# **Tech Maturity**

----

## What is Tech Maturity?
Tech Maturity is an open-source portal that measures the progress and maturity of software products. It helps teams identify growth opportunities to eliminate waste, set clearly defined targets, and measure progress all while working toward the ultimate goal of continuous delivery.

The model charts a clear path that can be completed in stages and allows flexibility for progressing through five key dimensions of software development: Code, Build & Test, Release, Operate, and Optimize.

The model can serve as a “cloud readiness” gauge that quantifies how close a product is to being ready for migration. This is achieved by establishing targets for a subset of capabilities that define the minimum requirements for any product or service in the public cloud. This gives teams who own legacy products a clear goal to work toward that they can easily track, and lets an organization operate in a decentralized, self-service way so that teams can run with their migrations without delay.

You can’t tell if you’re winning without a scoreboard, so the portal gathers, aggregates, and displays patterns from the assembled data and makes it visible to everyone. Strategically, Tech Maturity provides a key indicator of performance so teams can continually make value-driven improvements.

The best thing about the model is that it does not prescribe solutions. Rather, it offers standards with an aim to give teams a clear path towards efficient product development at scale. The model can be easily tailored to meet your specific needs, and has been successfully applied to products ranging from legacy systems to modern JavaScript libraries. It’s a great vehicle for sharing and rallying around a common vision.

----
## Try it out!
1. [Get Docker](https://www.docker.com/get-docker)
2. run `docker compose up` (or `docker-compose up` on older Docker)
3. open up `http://localhost:8080` in your web browser 🚀

----
## Running the tests
The app targets **Ruby 3.3** and **Rails 7.2**. The simplest way to run the
suite is inside the container (the image bundles headless Chromium for the
system tests):

```
docker compose run --rm -e RAILS_ENV=test techmaturity \
  sh -c "bin/rails db:prepare && bin/rails test && bin/rails test:system"
```

- `bin/rails test` runs the unit/controller tests.
- `bin/rails test:system` runs the Capybara/Cuprite system tests (headless
  Chromium) covering the dashboard charts and live product search.

To run locally instead of in Docker you need Ruby 3.3, a Postgres instance,
and Chromium on your PATH; then `bundle install` and the same `bin/rails`
commands.

## Contribution
1. Fork the project
2. Commit code changes to the forked repo
3. Squash the commit
4. Send a pull request and one of our team members will jump in
