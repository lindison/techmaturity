require "test_helper"

class AiRepoAnalyzerTest < ActiveSupport::TestCase
  setup do
    @framework = Framework.find_by(slug: "tech")
    @analyzer = AiRepoAnalyzer.new("/tmp", @framework)
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
