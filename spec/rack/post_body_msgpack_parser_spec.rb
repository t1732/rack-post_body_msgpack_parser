require 'spec_helper'
require 'json'
require "rack/post_body_msgpack_parser"

describe Rack::PostBodyMsgpackParser do
  let(:msgpack_data) { MessagePack.pack({"the_key" => "THE VALUE", "sample" => [1, 2, 3]}) }
  let(:json_data)    { JSON.dump({"the_key" => "THE VALUE", "sample" => [1, 2, 3]}) }

  context 'not override_params' do
    before do
      mock_app do
        use Rack::PostBodyMsgpackParser

        helpers do
          def msgpack_params
            @_params ||= request.env['rack.request.unpacked_form_hash']
          end
        end

        post '/test-it' do
          if msgpack_params
            "OK: keys: #{msgpack_params.keys}, values: #{msgpack_params.values}"
          else
            "No Data"
          end
        end
      end
    end

    it "should ignore post when posted normally" do
      post "/test-it", {foo: "bar"} do |response|
        expect(response.body).to eq("No Data")
      end
      expect(last_request.params.size).to eq(1)
    end

    it "should accept post by msgpack data" do
      header 'Content-Type', 'application/x-msgpack'
      post "/test-it", {}, {:input => msgpack_data} do |response|
        expect(response.body).to include("OK")
        expect(response.body).to include(%q(keys: ["the_key", "sample"]))
        expect(response.body).to include(%q(values: ["THE VALUE", [1, 2, 3]]))
      end
      expect(last_request.params).to be_empty
    end

    it "should ignore post by json data" do
      header 'Content-Type', 'application/json'
      post "/test-it", {}, {:input => json_data} do |response|
        expect(response.body).to eq("No Data")
      end
      expect(last_request.params).to be_empty
    end

    context "when content-type is x-msgpack but body is not msgpack" do
      it "should deny request" do
        header 'Content-Type', 'application/x-msgpack'
        post "/test-it", {}, {:input => json_data} do |response|
          expect(response.status).to eq(400)
          expect(response.body).to eq("")
        end
      end
    end
  end

  context 'override_params' do
    before do
      mock_app do
        use Rack::PostBodyMsgpackParser, override_params: true

        post '/test-it' do
          builder = ''
          params.each_pair do |key, value|
            builder << "#{key.to_s}=#{value.inspect} "
          end
          "OK: #{builder}"
        end
      end
    end

    it "should ignore post when posted normally" do
      post "/test-it", {foo: "bar"} do |response|
        expect(response.body).to include(%q(foo="bar"))
      end
      expect(last_request.params.size).to eq(1)
    end

    it "should accept post by msgpack data" do
      header 'Content-Type', 'application/x-msgpack'
      post "/test-it", {}, {:input => msgpack_data} do |response|
        expect(response.body).to include(%q(the_key="THE VALUE"))
        expect(response.body).to include(%q(sample=[1, 2, 3]))
      end
      expect(last_request.params.size).to eq(2)
    end

    it "should ignore post by json data" do
      header 'Content-Type', 'application/json'
      post "/test-it", {}, {:input => json_data} do |response|
        expect(response.body.length).to eq(4)
        expect(response.body).not_to include(%q(the_key="THE VALUE"))
        expect(response.body).not_to include(%q(sample=[1, 2, 3]))
      end
      expect(last_request.params).to be_empty
    end

    context "when content-type is x-msgpack but body is not msgpack" do
      it "should deny request" do
        header 'Content-Type', 'application/x-msgpack'
        post "/test-it", {}, {:input => json_data} do |response|
          expect(response.status).to eq(400)
          expect(response.body).to eq("")
        end
      end
    end

  end
end
