module Crucible
  module Tests
    class BaseTest

      include Crucible::Tests::Assertions

      BASE_SPEC_LINK = 'http://www.hl7.org/implement/standards/fhir'
      REST_SPEC_LINK = "#{BASE_SPEC_LINK}/http.html"

      # Base test fields, used in Crucible::Tests::Executor.list_all
      JSON_FIELDS = ['author','description','id','tests','title', 'multiserver']
      STATUS = {
        pass: 'pass',
        fail: 'fail',
        error: 'error',
        skip: 'skip'
      }

      def initialize(client, client2=nil)
        @client = client
        @client2 = client2
      end

      def multiserver
        false
      end

      def execute
        [{test_name => {
            test_file: test_name,
            tests: execute_test_methods
        }}]
      end

      def execute_test_methods(test_methods=nil)
        result = []
        setup if respond_to? :setup and not @metadata_only
        prefix = if @metadata_only then 'generating metadata' else 'executing' end
        methods = tests
        methods = tests & test_methods unless test_methods.blank?
        methods.each do |test_method|
          puts "[#{test_name}#{('_' + @resource_class.name.demodulize) if @resource_class}] #{prefix}: #{test_method}..."
          begin
            result << execute_test_method(test_method)
          rescue => e
            result << TestResult.new('ERROR', "Error #{prefix} #{test_method}", STATUS[:error], "#{test_method} failed, fatal error: #{e.message}", e.backtrace.join("\n")).to_hash.merge!({:test_method => test_method})
          end
        end
        teardown if respond_to? :teardown and not @metadata_only
        result
      end

      def execute_test_method(test_method)
        self.method(test_method).call().to_hash.merge!({:test_method => test_method})
      end

      def author
        # String identifying test file author
        self.class.name
      end

      def description
        # String containing test file description
        self.class.name
      end

      def id
        # String used to order test files for execution
        self.object_id.to_s
      end

      def test_name
        self.class.name.demodulize.to_sym
      end

      def tests(keys=nil)
        # Array of test methods within test file
        methods = self.methods.grep(/_test$/)
        if keys
          matches = []
          keys.each do |key|
            matches << methods.grep(/^#{key}/i)
          end
          methods = matches.flatten
        end
        methods
      end

      def title
        # String containing test file title
        self.class.name.split('::').last
      end

    end
  end
end
