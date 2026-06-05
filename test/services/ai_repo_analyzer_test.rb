require "test_helper"
require "tmpdir"

class AiRepoAnalyzerTest < ActiveSupport::TestCase
  setup do
    @framework = Framework.find_by(slug: "tech")
    @analyzer = AiRepoAnalyzer.new("/tmp", @framework)
  end

  test "chunks pack the whole repo into char-bounded pieces, splitting big files" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "big.rb"), "x" * (AiRepoAnalyzer::MAX_FILE * 2 + 100)) # forces splitting
      5.times { |i| File.write(File.join(dir, "f#{i}.rb"), "puts #{i}\n" * 40) }
      File.write(File.join(dir, "README.md"), "# readme")

      chunks = AiRepoAnalyzer.new(dir, @framework).send(:chunks)

      assert chunks.any?
      assert(chunks.all? { |c| c.size <= AiRepoAnalyzer::CHUNK_CHARS }, "no chunk exceeds the budget")
      assert_match(%r{big\.rb \(part \d+/\d+\)}, chunks.join, "a large file is split into labelled parts")
      assert_match(/README\.md/, chunks.first, "READMEs are placed first")
    end
  end

  test "deterministic_reduce keeps the highest level seen per capability" do
    observations = [
      { "slug" => "a3", "level" => 2, "evidence" => "some tests" },
      { "slug" => "a3", "level" => 4, "evidence" => "comprehensive tests" },
      { "slug" => "b5", "level" => 3, "evidence" => "ci pipeline" }
    ]

    rows = @analyzer.send(:deterministic_reduce, observations).index_by { |r| r["slug"] }

    assert_equal 4, rows["a3"]["level"]
    assert_equal 3, rows["b5"]["level"]
  end

  test "is unavailable in the test environment (no external calls)" do
    assert_not AiRepoAnalyzer.available?
  end

  test "parse_levels pulls a JSON array out of fenced/prose replies" do
    content = "Sure:\n```json\n[{\"slug\":\"a1\",\"level\":3,\"evidence\":\"self-documenting\"}]\n```"
    assert_equal([{ "slug" => "a1", "level" => 3, "evidence" => "self-documenting" }],
                 @analyzer.parse_levels(content))
    assert_equal [], @analyzer.parse_levels("no json here")
  end

  test "findings_from validates slugs and levels against the framework" do
    a1 = @framework.capabilities.find_by(slug: "a1")
    rows = [
      { "slug" => "a1",   "level" => 3,   "evidence" => "self-documenting code" },
      { "slug" => "a1",   "level" => 9,   "evidence" => "out of range" },  # dropped
      { "slug" => "nope", "level" => 2,   "evidence" => "unknown slug" },   # dropped
      { "slug" => "a2",   "level" => nil, "evidence" => "cannot tell" }     # dropped
    ]

    findings = @analyzer.findings_from(rows)

    assert_equal 1, findings.size
    assert_equal a1.name, findings.first.title
    assert_equal 3, findings.first.level
    assert_match(/AI:/, findings.first.note)
  end
end
