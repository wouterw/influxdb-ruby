require "spec_helper"
require "json"

describe InfluxDB::Client do
  let(:subject) do
    described_class.new(
      "database",
      {
        host: "influxdb.test",
        port: 9999,
        username: "username",
        password: "password",
        time_precision: "s"
      }.merge(args)
    )
  end

  let(:args) { {} }

  describe "#list_continuous_queries" do
    let(:query) { "SHOW CONTINUOUS QUERIES" }
    let(:database) { "testdb" }
    let(:response) do
      { "results" => [{ "series" => [{ "name" => "otherdb", "columns" => %w(name query),
                                       "values" =>
                                          [["clicks_per_hour", "CREATE CONTINUOUS QUERY clicks_per_hour ON otherdb BEGIN SELECT count(name) INTO \"otherdb\".\"default\".clicksCount_1h FROM \"otherdb\".\"default\".clicks GROUP BY time(1h) END"]] },
                                     { "name" => "testdb", "columns" => %w(name query),
                                       "values" =>
                                          [["event_counts", "CREATE CONTINUOUS QUERY event_counts ON testdb BEGIN SELECT count(type) INTO \"testdb\".\"default\".typeCount_10m_byType FROM \"testdb\".\"default\".events GROUP BY time(10m), type END"]] }] }] }
    end

    let(:expected_result) do
      [{ "name" => "event_counts", "query" => "CREATE CONTINUOUS QUERY event_counts ON testdb BEGIN SELECT count(type) INTO \"testdb\".\"default\".typeCount_10m_byType FROM \"testdb\".\"default\".events GROUP BY time(10m), type END" }]
    end

    before do
      stub_request(:get, "http://influxdb.test:9999/query").with(
        query: { u: "username", p: "password", q: query }
      ).to_return(body: JSON.generate(response), status: 200)
    end

    it "should GET a list of continuous queries for specified db only" do
      expect(subject.list_continuous_queries(database)).to eq(expected_result)
    end
  end

  describe "#create_continuous_query" do
    let(:name) { "event_counts_per_10m_by_type" }
    let(:database) { "testdb" }
    let(:query) do
      "SELECT COUNT(type) INTO typeCount_10m_byType FROM events GROUP BY time(10m), type"
    end
    let(:clause) do
      ["CREATE CONTINUOUS QUERY #{name} ON #{database} BEGIN", query, "END"].join("\n")
    end

    before do
      stub_request(:get, "http://influxdb.test:9999/query").with(
        query: { u: "username", p: "password", q: clause }
      )
    end

    it "should GET to create a new continuous query" do
      expect(subject.create_continuous_query(name, database, query)).to be_a(Net::HTTPOK)
    end
  end

  describe "#delete_continuous_query" do
    let(:name) { "event_counts_per_10m_by_type" }
    let(:database) { "testdb" }
    let(:query) { "DROP CONTINUOUS QUERY #{name} ON #{database}" }
    before do
      stub_request(:get, "http://influxdb.test:9999/query").with(
        query: { u: "username", p: "password", q: query }
      )
    end

    it "should GET to remove continuous query" do
      expect(subject.delete_continuous_query(name, database)).to be_a(Net::HTTPOK)
    end
  end
end
