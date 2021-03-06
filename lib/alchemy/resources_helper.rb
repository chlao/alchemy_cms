# frozen_string_literal: true

module Alchemy
  module ResourcesHelper
    # = Alchemy::ResourceHelper
    #
    # Used to DRY up resource like structures in Alchemy's admin backend in combination with Alchemy::Resource
    #
    # See Alchemy::Resource for examples how to initialize a resource_handler
    #

    def resource_window_size
      @resource_window_size ||= "420x#{100 + resource_handler.attributes.length * 40}"
    end

    def resource_instance_variable
      instance_variable_get("@#{resource_handler.resource_name}")
    end

    def resources_instance_variable
      instance_variable_get("@#{resource_handler.resources_name}")
    end

    def resource_url_proxy
      if resource_handler.in_engine?
        eval(resource_handler.engine_name)
      else
        main_app
      end
    end

    def resource_scope
      @_resource_scope ||= [resource_url_proxy].concat(resource_handler.namespace_for_scope)
    end

    def resources_path(resource_or_name = resource_handler.namespaced_resources_name, options = {})
      polymorphic_path (resource_scope + [resource_or_name]), options
    end

    def resource_path(resource = resource_handler.namespaced_resource_name, options = {})
      resources_path(resource, options)
    end

    def new_resource_path(options = {})
      new_polymorphic_path (resource_scope + [resource_handler.namespaced_resource_name]), options
    end

    def edit_resource_path(resource = nil, options = {})
      path_segments = (resource_scope + [resource] || resource_handler.resource_array)
      edit_polymorphic_path path_segments, options
    end

    def resource_name
      resource_handler.resource_name
    end

    def resource_model
      resource_handler.model
    end

    # Returns the value from resource attribute
    #
    # If the attribute has a relation, the related object's attribute value will be returned.
    #
    # The output will be truncated after 50 chars.
    # Pass another number to truncate then and pass false to disable this completely.
    #
    # @param [Alchemy::Resource] resource
    # @param [Hash] attribute
    # @option options [Hash] :truncate (50) The length of the value returned.
    #
    # @return [String]
    #
    def render_attribute(resource, attribute, options = {})
      if attribute[:relation]
        record = resource.send(attribute[:relation][:name])
        value = record.present? ? record.send(attribute[:relation][:attr_method]) : Alchemy.t(:not_found)
      elsif attribute[:type] == :datetime
        value = l(resource.send(attribute[:name]))
      else
        value = resource.send(attribute[:name])
      end

      options.reverse_merge!(truncate: 50)
      if options[:truncate]
        value.to_s.truncate(options.fetch(:truncate, 50))
      else
        value
      end
    end

    # Returns a options hash for simple_form input fields.
    def resource_attribute_field_options(attribute)
      options = {hint: resource_handler.help_text_for(attribute)}
      case attribute[:type].to_s
      when 'boolean'
        options
      when 'date', 'datetime'
        options.merge as: 'string',
          input_html: {
            type: attribute[:type].to_s,
            value: l(resource_instance_variable.send(attribute[:name]) || Time.current,
              format: "#{attribute[:type]}picker".to_sym
            )
          }
      when 'time'
        options.merge(as: 'time')
      when 'text'
        options.merge(as: 'text', input_html: {rows: 4})
      else
        options.merge(as: 'string')
      end
    end

    # Renders the human model name with a count as h1 header
    def resources_header
      content_tag :h1, "#{resources_instance_variable.total_count} #{resource_model.model_name.human(count: resources_instance_variable.total_count)}", class: 'resources-header'
    end

    # Returns true if the resource contains any relations
    def contains_relations?
      resource_handler.resource_relations.present?
    end

    # Returns an array of all resource_relations names
    def resource_relations_names
      resource_handler.resource_relations.collect { |_k, v| v[:name].to_sym }
    end

    # Returns the attribute's column for sorting
    #
    # If the attribute contains a resource_relation, then the table and column for related model will be returned.
    #
    def sortable_resource_header_column(attribute)
      if relation = attribute[:relation]
        "#{relation[:model_association].name}_#{relation[:attr_method]}"
      else
        attribute[:name]
      end
    end

    # Renders the row for a resource record in the resources table.
    #
    # This helper has a nice fallback. If you create a partial for your record then this partial will be rendered.
    #
    # Otherwise the default +app/views/alchemy/admin/resources/_resource.html.erb+ partial gets rendered.
    #
    # == Example
    #
    # For a resource named +Comment+ you can create a partial named +_comment.html.erb+
    #
    #   # app/views/admin/comments/_comment.html.erb
    #   <tr>
    #     <td><%= comment.title %></td>
    #     <td><%= comment.body %></td>
    #   </tr>
    #
    # NOTE: Alchemy gives you a local variable named like your resource
    #
    def render_resources
      render partial: resource_name, collection: resources_instance_variable
    rescue ActionView::MissingTemplate
      render partial: 'resource', collection: resources_instance_variable
    end

    # Returns all the params necessary to get you back from where you where
    # before: the Ransack query and the current page.
    #
    def current_location_params
      {
        q: params[:q],
        page: params[:page],
        tagged_with: params[:tagged_with],
        filter: params[:filter]
      }
    end

    def resource_has_tags
      resource_model.respond_to?(:tag_counts) && resource_model.tag_counts.any?
    end

    def resource_has_filters
      resource_model.respond_to?(:alchemy_resource_filters)
    end

    def resource_filter_select
      resource_model.alchemy_resource_filters.map do |filter_scope|
        [
          Alchemy.t(filter_scope.to_sym, scope: ['resources', resource_name, 'filters']),
          filter_scope
        ]
      end
    end
  end
end
