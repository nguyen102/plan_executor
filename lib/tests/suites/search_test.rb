module Crucible
  module Tests
    class SearchTest < BaseSuite

      attr_accessor :resource_class
      attr_accessor :conformance
      attr_accessor :searchParams
      attr_reader :canSearchById

      def execute(resource_class = nil)
        if resource_class
          @resource_class = resource_class
          {"SearchTest_#{@resource_class.name.demodulize}" => execute_test_methods}
        else
          results = {}
          Crucible::Tests::BaseSuite.fhir_resources.each do |klass|
            @resource_class = klass
            results.merge!({"SearchTest_#{@resource_class.name.demodulize}" => execute_test_methods})
          end
          results
        end
      end

      def id
        suffix = resource_class
        suffix = resource_class.name.demodulize if !resource_class.nil?
        "SearchTest_#{suffix}"
      end

      def description
        "Execute suite of searches for #{resource_class.name.demodulize} resources."
      end

      def category
        resource = @resource_class.nil? ? "Uncategorized" : resource_category(@resource_class)
        {id: "search_#{resource.parameterize}", title: "#{resource} Search"}
      end

      def initialize(client1, client2 = nil)
        super(client1, client2)
      end

      # this allows results to have unique ids for resource based tests
      def result_id_suffix
        resource_class.name.demodulize
      end

      def supplement_test_description(desc)
        "#{desc} #{resource_class.name.demodulize}"
      end

      #
      # Search Test
      # 1. First, get the conformance statement.
      # 2. Lookup the allowed search parameters for each resource.
      # 3. Perform suite of tests against each resource.
      #
      def setup
        @conformance = @client.conformance_statement if @conformance.nil?

        @canSearchById = false

        unless @conformance.nil?
          @conformance.rest.each do |rest|
            rest.resource.each do |resource|
              @searchParams = resource.searchParam if (resource.type.downcase == "#{@resource_class.name.demodulize.downcase}")
            end
          end
        end

        index = @searchParams.find_index { |item| item.name == "_id" } if !@searchParams.nil?
        @canSearchById = !index.nil?
      end


      # Parameters for all resources
      #   _id
      #   _lastUpdated
      #   _tag
      #   _profile
      #   _security
      #   _text
      #   _content
      #   _list
      #   _query
      # Search result parameters
      #   _sort
      #   _count
      #   _include
      #   _revinclude
      #   _summary
      #   _elements
      #   _contained
      #   _containedType

      # If want to search on post set `[true,false].each do |flag|`
      # [true,false].each do |flag|
      [false].each do |flag|
        action = 'GET'
        action = 'POST' if flag

        test "S003#{action[0]}", "Search limit by _count (#{action})" do
          metadata {
            define_metadata('search')
          }
          options = {
              :search => {
                  :flag => flag,
                  :compartment => nil,
                  :parameters => {
                      '_count' => '1'
                  }
              }
          }
          reply = @client.search(@resource_class, options)
          assert_response_ok(reply)
          assert_bundle_response(reply)
          assert (1 >= reply.resource.entry.size), 'The server did not return the correct number of results.'
        end

        # ********************************************************* #
        # _____________________Sprinkler Tests_____________________ #
        # ********************************************************* #

        test "SE01#{action[0]}", "Search without criteria (#{action})" do
          metadata {
            links "#{BASE_SPEC_LINK}/#{resource_class.name.demodulize.downcase}.html"
            links "#{REST_SPEC_LINK}#search"
            links "#{REST_SPEC_LINK}#read"
            validates resource: resource_class.name.demodulize, methods: ['read', 'search']
          }
          options = {
              :search => {
                  :flag => flag,
                  :compartment => nil,
                  :parameters => nil
              }
          }
          reply = @client.search(@resource_class, options)
          assert_response_ok(reply)
          assert_bundle_response(reply)

          replyB = @client.read_feed(@resource_class)

          # AuditEvent
          if resource_class == get_resource(:AuditEvent)
            count = (reply.resource.total - replyB.resource.total).abs
            assert (count <= 1), 'Searching without criteria did not return all the results.'
          else
            assert !replyB.resource.nil?, 'Searching without criteria did not return any results.'
            assert !reply.resource.nil?, 'Searching without criteria did not return any results.'
            assert !replyB.resource.total.nil?, 'Search bundle returned does not report a total entry count.'
            assert !reply.resource.total.nil?, 'Search bundle returned does not report a total entry count.'
            assert_equal replyB.resource.total, reply.resource.total, 'Searching without criteria did not return all the results.'
          end
        end
      end

      def define_metadata(method)
        links "#{REST_SPEC_LINK}##{method}"
        links "#{BASE_SPEC_LINK}/#{resource_class.name.demodulize.downcase}.html"
        validates resource: resource_class.name.demodulize, methods: [method]
      end

    end
  end
end
