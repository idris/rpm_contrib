if defined?(::Mongo) && !NewRelic::Control.instance['disable_mongodb']

  module RPMContrib
    module Instrumentation
      module Mongo
        RPM_TRACEABLE_MONGO_COMMANDS = %w(count distinct findandmodify group mapreduce)
      end
    end
  end

  Mongo::Collection.class_eval do
    include NewRelic::Agent::MethodTracer

    add_method_tracer :insert, 'Database/#{@name}/insert'
    add_method_tracer :remove, 'Database/#{@name}/remove'
    add_method_tracer :update, 'Database/#{@name}/update'
  end


  Mongo::Cursor.class_eval do
    include NewRelic::Agent::MethodTracer

    def refresh_with_newrelic_trace *args
      # cursor_id.zero? means we have all the data
      return refresh_without_newrelic_trace(*args) if (@cursor_id || 1).zero?

      collection_name = @collection.name
      method_name = @selector.keys.first
      if RPMContrib::Instrumentation::Mongo::RPM_TRACEABLE_MONGO_COMMANDS.include? method_name.to_s
        if collection_name == Mongo::DB::SYSTEM_COMMAND_COLLECTION
          collection_name = @selector[method_name]
          if method_name == 'group'
            collection_name = collection_name['ns']
          end
        end
      else
        method_name = 'find'
      end

      self.class.trace_execution_scoped("Database/#{collection_name}/#{method_name}") do
        refresh_without_newrelic_trace(*args)
      end
    end

    if private_method_defined?(:refresh) || method_defined?(:refresh)
      alias_method :refresh_without_newrelic_trace, :refresh
      alias_method :refresh, :refresh_with_newrelic_trace
    elsif private_method_defined?(:refill_via_get_more) || method_defined?(:refill_via_get_more)
      # in older versions of mongo-ruby-driver, refresh was called refill_via_get_more
      alias_method :refresh_without_newrelic_trace, :refill_via_get_more
      alias_method :refill_via_get_more, :refresh_with_newrelic_trace
    end

  end
end