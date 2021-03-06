# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'openssl'
require 'ostruct'
require 'json'

module Mobile
  module Pesa
    class RegisterUrls
      attr_reader :short_code, :response_type, :confirmation_url, :validation_url

      def self.call(short_code:, response_type:, confirmation_url:, validation_url:)
        new(short_code, response_type, confirmation_url, validation_url).call
      end

      def initialize(short_code, response_type, confirmation_url, validation_url)
        @short_code = short_code
        @response_type = response_type
        @confirmation_url = confirmation_url
        @validation_url = validation_url
      end

      def call
        url = URI("https://sandbox.safaricom.co.ke/mpesa/c2b/v1/registerurl")

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        request = Net::HTTP::Post.new(url)
        request["Content-Type"] = 'application/json'
        request["Authorization"] = "Bearer #{token}"
        request.body = JSON.dump(body)

        response = http.request(request)
        parsed_body = JSON.parse(response.read_body)

        if parsed_body.key?("errorCode")
          error = OpenStruct.new(
            error_code: parsed_body["errorCode"],
            error_message: parsed_body["errorMessage"],
            request_id: parsed_body["requestId"]
          )
          OpenStruct.new(result: nil, error: error)
        else
          result = OpenStruct.new(
            originator_converstion_id: parsed_body["OriginatorConverstionID"],
            response_code: parsed_body["ResponseCode"],
            response_description: parsed_body["ResponseDescription"]
          )
          OpenStruct.new(result: result, error: nil)
        end
      rescue JSON::ParserError => error
        OpenStruct.new(result: nil, error: error)
      end

      private

      def token
        Mobile::Pesa::Authorization.call.result.access_token
      end

      def body
        {
          "ShortCode": short_code,
          "ResponseType": response_type, # Cancelled Completed
          "ConfirmationURL": confirmation_url,
          "ValidationURL": validation_url
        }
      end
    end
  end
end
