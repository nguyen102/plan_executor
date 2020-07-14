module Crucible
  module Tests
    class SprinklerSearchTest < BaseSuite

      attr_accessor :use_post

      def id
        'Search001'
      end

      def description
        'Initial Sprinkler tests for testing search capabilities.'
      end

      def initialize(client1, client2=nil)
        super(client1, client2)
        @category = {id: 'core_functionality', title: 'Core Functionality'}
      end

      def setup
        # Create a patient with gender:missing
        @resources = Crucible::Generator::Resources.new(fhir_version)
        @patient = @resources.minimal_patient
        @patient.identifier = [get_resource(:Identifier).new]
        @patient.identifier[0].value = SecureRandom.urlsafe_base64
        @patient.gender = nil
        result = @client.create(@patient)
        @patient_id = result.id

        # read all the patients
        @read_entire_feed=true
        @client.use_format_param = true
        reply = @client.read_feed(get_resource(:Patient))

        @read_entire_feed=false if (!reply.nil? && reply.code!=200)
        @total_count = 0
        @entries = []

        mute_response_body 'The body of the Sprinkler Search setup responses are not stored for performance reasons.' do
          while reply != nil && !reply.resource.nil?
            @total_count += reply.resource.entry.size
            @entries += reply.resource.entry
            reply = @client.next_page(reply)
            @read_entire_feed=false if (!reply.nil? && reply.code!=200)
          end
        end

        # create a condition matching the first patient
        # @condition = ResourceGenerator.generate(get_resource(:Condition),3)
        # if fhir_version == :dstu2
        #   @condition.patient = @entries.first.try(:resource).try(:to_reference)
        # else
        #   @condition.subject = @entries.first.try(:resource).try(:to_reference)
        # end
        #
        # reply = @client.create(@condition)
        # @condition_id = reply.id
        # puts "Condition Id #{@condition_id}"
        # puts "Client response #{@client.reply.inspect}"

        # create some observations
        @obs_a = create_observation(2.0)
        @obs_b = create_observation(1.96)
        @obs_c = create_observation(2.04)
        @obs_d = create_observation(1.80)
        @obs_e = create_observation(5.12)
        @obs_f = create_observation(6.12)
      end

      def create_observation(value)
        observation = get_resource(:Observation).new
        observation.status = 'preliminary'
        code = get_resource(:Coding).new
        code.system = 'http://loinc.org'
        code.code = '2164-2'
        observation.code = get_resource(:CodeableConcept).new
        observation.code.coding = [ code ]
        observation.valueQuantity = get_resource(:Quantity).new
        observation.valueQuantity.system = 'http://unitsofmeasure.org'
        observation.valueQuantity.value = value
        observation.valueQuantity.unit = 'mmol'
        body = get_resource(:Coding).new
        body.system = 'http://snomed.info/sct'
        body.code = '182756003'
        observation.bodySite = get_resource(:CodeableConcept).new
        observation.bodySite.coding = [ body ]
        Crucible::Generator::Resources.new(fhir_version).tag_metadata(observation)
        reply = @client.create(observation)
        reply.id
      end

      def teardown
        @client.use_format_param = false
        @client.destroy(get_resource(:Patient), @patient_id) if @patient_id
        @client.destroy(get_resource(:Condition), @condition_id) if @condition_id
        @client.destroy(get_resource(:Observation), @obs_a) if @obs_a
        @client.destroy(get_resource(:Observation), @obs_b) if @obs_b
        @client.destroy(get_resource(:Observation), @obs_c) if @obs_c
        @client.destroy(get_resource(:Observation), @obs_d) if @obs_d
        @client.destroy(get_resource(:Observation), @obs_e) if @obs_e
        @client.destroy(get_resource(:Observation), @obs_f) if @obs_f
      end

    # If want to search on post set `[true,false].each do |flag|`
    [false].each do |flag|
      action = 'GET'
      action = 'POST' if flag

      test "SE01#{action[0]}",'Search patients without criteria (except _count)' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          validates resource: "Patient", methods: ["search"]
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
        reply = @client.search(get_resource(:Patient), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        assert_equal 1, reply.resource.entry.size, 'The server did not return the correct number of results.'
      end

      test "SE02#{action[0]}", 'Search on non-existing resource' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
        }
        options = {
          :resource => Crucible::Tests::SprinklerSearchTest,
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => nil
          }
        }
        reply = @client.search_all(options)
        assert( (reply.code >= 400 && reply.code < 600), 'If the search fails, the return value should be status code 4xx or 5xx.', reply)
      end

      # test "SE05.1#{action[0]}", 'Search condition by patient reference id' do
      #   metadata {
      #     links "#{REST_SPEC_LINK}#search"
      #     links "#{BASE_SPEC_LINK}/search.html"
      #     links "#{BASE_SPEC_LINK}/condition.html#search"
      #     validates resource: "Condition", methods: ["search"]
      #   }
      #   skip 'Could not find a patient to search on in setup.' unless @read_entire_feed
      #   # pick some search parameters... we previously created
      #   patient_id = @entries[0].resource.id
      #
      #   # next, we're going execute a series of searches for conditions referencing the patient
      #   options = {
      #     :search => {
      #       :flag => flag,
      #       :compartment => nil,
      #       :parameters => {
      #         'patient' => patient_id
      #       }
      #     }
      #   }
      #   reply = @client.search(get_resource(:Condition), options)
      #   puts "Search #{reply.inspect}"
      #   assert_response_ok(reply)
      #   assert_bundle_response(reply)
      #   reply.resource.entry.each do |e|
      #     if fhir_version == :dstu2
      #       assert((e.resource.patient.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
      #     else
      #       assert((e.resource.subject.reference == @entries.first.resource.to_reference.reference),"The search returned a Condition that doesn't match the Patient.")
      #     end
      #   end
      # end

      test "SE24#{action[0]}", 'Search with non-existing parameter' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#search"
          validates resource: "Patient", methods: ["search"]
        }
        # non-existing parameters should be ignored
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              'bonkers' => 'foobar'
            }
          }
        }
        reply = @client.search(get_resource(:Patient), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

      test "SE25#{action[0]}", 'Search with malformed parameters' do
        metadata {
          links "#{REST_SPEC_LINK}#search"
          links "#{BASE_SPEC_LINK}/search.html"
          links "#{BASE_SPEC_LINK}/patient.html#search"
          validates resource: "Patient", methods: ["search"]
        }
        # a malformed parameters are non-existing parameters, and they should be ignored
        options = {
          :search => {
            :flag => flag,
            :compartment => nil,
            :parameters => {
              '...' => 'foobar'
            }
          }
        }
        reply = @client.search(get_resource(:Patient), options)
        assert_response_ok(reply)
        assert_bundle_response(reply)
      end

    end # EOF [true,false].each

    end
  end
end
