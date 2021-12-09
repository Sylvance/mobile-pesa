require 'uri'
require 'net/http'
require 'openssl'
require 'ostruct'
require 'json'
require 'base64'

module M
  module Pesa
    class StkPushViaPaybillNumber
      attr_reader :amount, :phone_number, :account_number, :pay_bill_number

      def self.call(amount:, phone_number:, account_number:, pay_bill_number:)
        new(amount, phone_number, account_number, pay_bill_number).call
      end

      def initialize(amount, phone_number, account_number, pay_bill_number)
        @amount = amount
        @phone_number = phone_number
        @account_number = account_number
        @pay_bill_number = pay_bill_number
      end

      def call
        url = URI("https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest")

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
          error = OpenStruct.new(error_code: parsed_body["errorCode"], error_message: parsed_body["errorMessage"], request_id: parsed_body["requestId"])
          OpenStruct.new(result: nil, error: error)
        else
          result = OpenStruct.new(
            merchant_request_id: parsed_body["MerchantRequestID"],
            checkout_request_id: parsed_body["CheckoutRequestID"],
            response_code: parsed_body["ResponseCode"],
            response_description: parsed_body["ResponseDescription"],
            customer_message: parsed_body["CustomerMessage"]
          )
          OpenStruct.new(result: result, error: nil)
        end
      rescue JSON::ParserError => error
        OpenStruct.new(result: nil, error: error)
      end

      private

      def token
        M::Pesa::Authorization.call.result.access_token
      end

      def body
        {
          "BusinessShortCode": pay_bill_number,
          "Password": password,
          "Timestamp": timestamp.to_s,
          "TransactionType": "CustomerPayBillOnline",
          "Amount": amount,
          "PartyA": phone_number,
          "PartyB": pay_bill_number,
          "PhoneNumber": phone_number,
          "CallBackURL": M::Pesa.configuration.callback_url,
          "AccountReference": account_number,
          "TransactionDesc": "Payment of X"
        }
      end

      def password
        Base64.strict_encode64("#{pay_bill_number}#{M::Pesa.configuration.pass_key}#{timestamp}")
      end

      def timestamp
        Time.now.strftime('%Y%m%d%H%M%S').to_i
      end
    end
  end
end
