# frozen_string_literal: true

module Nanoc
  module Core
    class IdentifiableCollectionView < ::Nanoc::Core::View
      include Enumerable

      NOTHING = Object.new

      # @api private
      def initialize(objects, context)
        super(context)
        @objects = objects
      end

      # @api private
      def _unwrap
        @objects
      end

      # @abstract
      #
      # @api private
      def view_class
        raise NotImplementedError
      end

      # Calls the given block once for each object, passing that object as a parameter.
      #
      # @yieldparam [#identifier] object
      #
      # @yieldreturn [void]
      #
      # @return [self]
      def each
        @context.dependency_tracker.bounce(_unwrap, raw_content: true)
        @objects.each { |i| yield view_class.new(i, @context) }
        self
      end

      # @return [Integer]
      def size
        @context.dependency_tracker.bounce(_unwrap, raw_content: true)
        @objects.size
      end

      # Finds all objects whose identifier matches the given argument.
      #
      # @param [String, Regex] arg
      #
      # @return [Enumerable]
      def find_all(arg = NOTHING, &block)
        if NOTHING.equal?(arg)
          @context.dependency_tracker.bounce(_unwrap, raw_content: true)
          return @objects.map { |i| view_class.new(i, @context) }.select(&block)
        end

        prop_attribute =
          case arg
          when String, Nanoc::Core::Identifier
            [arg.to_s]
          when Regexp
            [arg]
          else
            true
          end

        @context.dependency_tracker.bounce(_unwrap, raw_content: prop_attribute)
        @objects.find_all(arg).map { |i| view_class.new(i, @context) }
      end

      # Finds all objects that have the given attribute key/value pair.
      #
      # @example
      #
      #     @items.where(kind: 'article')
      #     @items.where(kind: 'article', year: 2020)
      #
      # @return [Enumerable]
      def where(**hash)
        unless Nanoc::Core::Feature.enabled?(Nanoc::Core::Feature::WHERE)
          raise(
            Nanoc::Core::TrivialError,
            '#where is experimental, and not yet available unless the corresponding feature flag is turned on. Set the `NANOC_FEATURES` environment variable to `where` to enable its usage. (Alternatively, set the environment variable to `all` to turn on all feature flags.)',
          )
        end

        @context.dependency_tracker.bounce(_unwrap, attributes: hash)

        # IDEA: Nanoc could remember (from the previous compilation) how many
        # times #where is called with a given attribute key, and memoize the
        # key-to-identifiers list.
        found_objects = @objects.select do |i|
          hash.all? { |k, v| i.attributes[k] == v }
        end

        found_objects.map { |i| view_class.new(i, @context) }
      end

      # @overload [](string)
      #
      #   Finds the object whose identifier matches the given string.
      #
      #   If the glob syntax is enabled, the string can be a glob, in which case
      #   this method finds the first object that matches the given glob.
      #
      #   @param [String] string
      #
      #   @return [nil] if no object matches the string
      #
      #   @return [#identifier] if an object was found
      #
      # @overload [](regex)
      #
      #   Finds the object whose identifier matches the given regular expression.
      #
      #   @param [Regex] regex
      #
      #   @return [nil] if no object matches the regex
      #
      #   @return [#identifier] if an object was found
      def [](arg)
        prop_attribute =
          case arg
          when String, Nanoc::Core::Identifier
            [arg.to_s]
          when Regexp
            [arg]
          else
            true
          end

        @context.dependency_tracker.bounce(_unwrap, raw_content: prop_attribute)
        res = @objects[arg]
        res && view_class.new(res, @context)
      end
    end
  end
end
