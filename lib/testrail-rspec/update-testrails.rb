require_relative 'api-client'

module TestrailRSpec
  class UpdateTestRails
    attr_accessor :client

    def initialize(scenario, config: {})
      @scenario = scenario

      if File.exist? './testrail_config.yml'
        @config = YAML.load_file("./testrail_config.yml")['testrail']
        raise 'TestRail configuration file not loaded successfully' if @config.nil?
      end

      if !config.nil? && !config.empty?
        @config = (@config || {}).merge(config)
      end

      if @config.nil? || @config.empty?
        raise 'TestRail configuration file or hash is required'
      end

      setup_testrail_client
    end

    def upload_result

      response = {}

      case_list = []
      @scenario.metadata[:description].split(' ').map do |e|
        val = e.scan(/\d+/).first
        next if val.nil?
        case_list << val
      end

      return if case_list.empty?

      if (@scenario.exception) && (!@scenario.exception.message.include? 'pending')
        status_id = get_status_id 'failed'.to_sym
        message = @scenario.exception.message
      elsif @scenario.skipped?
        status_id = get_status_id 'blocked'.to_sym
        message = "This test scenario is skipped from test execution"
      elsif @scenario.pending?
        status_id = get_status_id 'blocked'.to_sym
        message = "This test scenario is pending for test execution"
      else
        status_id = get_status_id 'passed'.to_sym
        message = "This test scenario was automated and passed successfully"
      end

      @run_id ||= @config['run_id']
      @run_id = @@run_id rescue @@run_id = nil unless @config['run_id']
      @run_id = @@run_id = client.create_test_run("add_run/#{@config['project_id']}", { "suite_id": @config['suite_id']}) if @run_id.nil?

      case_list.map do |case_id|
        response = client.send_post(
            "add_result_for_case/#{@run_id}/#{case_id}",
            { status_id: status_id, comment: message }
        )
      end

      response
    end

    def fetch_status_ids
      client.send_get('get_statuses')
    end

    private

    def setup_testrail_client
      @client = TestRail::APIClient.new(@config['url'])
      @client.user = @config['user']
      @client.password = @config['password']
    end

    def get_status_id(status)
      case status
      when :passed
        1
      when :blocked
        2
      when :untested
        3
      when :retest
        4
      when :failed
        5
      when :undefined
        raise 'missing step definition'
      else
        raise 'unexpected scenario status passed'
      end
    end
  end
end
