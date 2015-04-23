# Copied from a great job
# https://github.com/rack/rack-contrib/blob/master/lib/rack/contrib/post_body_content_type_parser.rb

require "rack"
require "msgpack"

module Rack
  class PostBodyMsgpackParser
    MSGPACK_MIME_TYPES = ["application/x-msgpack", "application/x-mpac"]

    def initialize(app, override_params: false)
      @app = app
      @override_params = override_params
    end

    def call(env)
      @env = env
      body = post_body

      if MSGPACK_MIME_TYPES.include?(Rack::Request.new(env).media_type) && body.length > 0
        unpacked_body = MessagePack.unpack(body)
        env.update('rack.request.unpacked_form_hash' => unpacked_body)
        if @override_params
          env.update('rack.request.form_hash' => unpacked_body, 'rack.request.form_input' => rack_input)
        end
      end
      @app.call(env)
    rescue MessagePack::MalformedFormatError => e
      env['rack.errors'].puts e.inspect
      [400, {}, []]
    end

    private

    def post_body
      rack_input.read
    ensure
      rack_input.rewind
    end

    def rack_input
      @env['rack.input']
    end
  end
end

require "rack/post_body_msgpack_parser/version"
