# frozen_string_literal: true
require 'html/pipeline'
require 'yaml'
require 'extended-markdown-filter'

module JsonSchemaDocs
  class Renderer
    include Helpers

    attr_reader :options

    def initialize(parsed_schema, options)
      @parsed_schema = parsed_schema
      @options = options

      unless @options[:templates][:default].nil?
        @default_layout = ERB.new(File.read(@options[:templates][:default]))
      end

      @pipeline_config = @options[:pipeline_config] || {}
      pipeline = @pipeline_config[:pipeline] || {}
      context = @pipeline_config[:context] || {}

      filters = pipeline.map do |f|
        if filter?(f)
          f
        else
          key = filter_key(f)
          filter = HTML::Pipeline.constants.find { |c| c.downcase == key }
          # possibly a custom filter
          if filter.nil?
            Kernel.const_get(f)
          else
            HTML::Pipeline.const_get(filter)
          end
        end
      end

      @pipeline = HTML::Pipeline.new(filters, context)
    end

    def render(contents, meta: {})
      opts = meta.merge({ base_url: @options[:base_url], output_dir: @options[:output_dir] }).merge(helper_methods)

      contents = to_html(contents, context: opts)
      return contents if @default_layout.nil?
      opts[:content] = contents
      @default_layout.result(OpenStruct.new(opts).instance_eval { binding })
    end

    def to_html(string, context: {})
      @pipeline.to_html(string, context)
    end

    private

    def filter_key(s)
      s.downcase
    end

    def filter?(f)
      f < HTML::Pipeline::Filter
    rescue LoadError, ArgumentError
      false
    end
  end
end
