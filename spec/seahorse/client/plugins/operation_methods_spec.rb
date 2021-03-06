require 'spec_helper'

module Seahorse
  module Client
    module Plugins
      describe OperationMethods do

        let(:client_class) do
          klass = Client::Base.define(api: {
            'operations' => {
              'Operation1' => { 'name' => 'Operation1' },
              'Operation2' => { 'name' => 'Operation2' },
              'Operation3' => { 'name' => 'Operation3' }
            }
          })
          klass.add_plugin(DummySendPlugin)
          klass
        end

        let(:client) { client_class.new endpoint: 'http://localhost' }

        let(:operations) { [:operation_1, :operation_2, :operation_3] }

        it 'adds methods for every operation in the API model' do
          expect(client.methods).to include(*operations.map(&:to_sym))
        end

        it 'sets up the method to call build_request and sends it' do
          client_class.remove_plugin(ParamValidation)
          expect(client).to receive(:build_request).
            with(:operation_1, param: 'X').and_call_original
          expect(client.operation_1(param: 'X').data).to eq(result: 'success')
        end

        it 'passes block arguments to the #send_request method' do
          req = double('request')
          allow(client).to receive(:build_request).and_return(req)
          allow(req).to receive(:send_request).
            and_yield('chunk1').
            and_yield('chunk2').
            and_yield('chunk3')

          chunks = []
          client.operation_1 do |chunk|
            chunks << chunk
          end
          expect(chunks).to eq(%w(chunk1 chunk2 chunk3))
        end

        it 'can be removed from client' do
          next_client_class = Class.new(client_class)
          next_client_class.remove_plugin OperationMethods
          client = next_client_class.new(endpoint:'http://foo.com')

          expect(client.methods).not_to include(*operations.map(&:to_sym))
          expect { client.operation1 }.to raise_error(NoMethodError)
        end

        it 'defines a helper that returns the list of valid operation names' do
          expect(client.operation_names).to eq(operations)
        end

        it 'only registers methods on the client class once' do
          expect(client_class).to receive(:define_method).
            with(:operation_names).exactly(1).times
          operations.each do |operation_name|
            expect(client_class).to receive(:define_method).
              with(operation_name).exactly(1).times
          end
          client_class.new(endpoint: 'http://localhost')
        end

      end
    end
  end
end
