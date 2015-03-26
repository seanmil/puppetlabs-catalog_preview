module PuppetX::Puppetlabs::Migration::CatalogDeltaModel
  # The super class of all elements in the CatalogDelta model
  #
  # @abstract
  # @api public
  class ModelObject
    # Creates a hash from the instance variables of this object. The keys will be symbols
    # corresponding to the attribute names (without leading '@'). The process of creating
    # a hash is recursive in the sens that all ModelObject instances found by traversing
    # the values of the instance variables will be converted too.
    #
    # @return [Hash<Symbol,Object>] a Symbol keyed hash with all attributes in this object
    #
    # @api public
    def to_hash
      hash = {}
      instance_variables.each do |iv|
        val = hashify(instance_variable_get(iv))
        hash[:"#{iv.to_s[1..-1]}"] = val unless val.nil?
      end
      hash
    end

    # Asserts that _value_ is of class _expected_type_ and raises an ArgumentError when that's not the case
    #
    # @param expected_type [Class]
    # @param value [Object]
    # @param default [Object]
    # @return [Object] the _value_ argument or _default_ argument when _value_ is nil
    #
    # @api private
    def assert_type(expected_type, value, default = nil)
      value = default if value.nil?
      raise ArgumentError "Expected an instance of #{expected_type.name}. Got #{value.class.name}" unless value.nil? || value.is_a?(expected_type)
      value
    end
    private :assert_type

    # Asserts that _value_ is a boolean and raises an ArgumentError when that's not the case
    #
    # @param value [Object]
    # @param default [Boolean]
    # @return [Boolean] the _value_ argument or _default_ argument when _value_ is nil
    #
    # @api private
    def assert_boolean(value, default)
      value = default if value.nil?
      raise ArgumentError "Expected an instance of Boolean. Got #{value.class.name}" unless value == true || value == false
      value
    end
    private :assert_boolean

    # Converts ModelObject to Hash and traverses Array and Hash objects to
    # call this method recursively on each element. Object that are not
    # ModelObject, Array, or Hash are returned verbatim
    #
    # @param val [Object] The value to hashify
    # @return [Object] the val argument, possibly converted
    #
    # @api private
    def hashify(val)
      case val
      when ModelObject
        val.to_hash
      when Hash
        Hash.new(val.each_pair {|k, v| [k, hashify(v)]})
      when Array
        val.map {|v| hashify(v) }
      else
        val
      end
    end
    private :hashify
  end

  # Denotes a line in a file
  #
  # @api public
  class Location < ModelObject
    # @!attribute [r] file
    #   @api public
    #   @return [String] the file name
    attr_reader :file

    # @!attribute [r] line
    #   @api public
    #   @return [Integer]
    attr_reader :line

    # @param file [String] the file name
    # @param line [Integer] the line in the file
    def initialize(file, line)
      @file = file
      @line = line
    end
  end

  # An element in the model that contains an Integer _diff_id_
  #
  # @abstract
  # @api public
  class Diff < ModelObject
    # @!attribute [r] diff_id
    #   @api public
    #   @return [Integer] the id of this element
    attr_reader :diff_id

    # Assigns id numbers to this object and contained objects. The id is incremented
    # once for each assignment that is made.
    #
    # @param id [Integer] The id to set
    # @return [Integer] The incremented id
    #
    # @api private
    def assign_ids(id)
      @diff_id = id
      id + 1
    end

    # Calls #assign_ids(id) all elements in the array while keeping track of the assinged id
    #
    # @param id [Integer] The id to set
    # @return [Integer] The incremented id
    #
    # @api private
    def assign_ids_on_each(start, array)
      array.nil? ? start : array.inject(start) { |n, a| a.assign_ids(n) }
    end
    private :assign_ids_on_each
  end

  # A Resource Attribute. Attributes stems from parameters, and information encoded in the resource (i.e. `exported`
  # or `tags`)
  #
  # @api public
  class Attribute < Diff
    # @!attribute [r] name
    #   @api public
    #   @return [String] the attribute name
    attr_reader :name

    # @!attribute [r] value
    #   @api public
    #   @return [Object] the attribute value
    attr_reader :value

    # @param name [String] the attribute name
    # @param value [Object] the attribute value
    def initialize(name, value)
      @name = name
      @value = value
    end
  end

  # A Catalog Edge
  #
  # @api public
  class Edge < Diff
    # @!attribute [r] source
    #   @api public
    #   @return [String] the edge source
    attr_reader :source

    # @!attribute [r] target
    #   @api public
    #   @return [String] the edge target
    attr_reader :target

    # @param source [String]
    # @param target [String]
    def initialize(source, target)
      @source = source
      @target = target
    end

    def ==(other)
      other.instance_of?(Edge) && source == other.source && target == other.target
    end
  end

  # Represents a conflicting attribute, i.e. an attribut that has the same name but different
  # values in the compared catalogs.
  #
  # @api public
  class AttributeConflict < Diff
    # @!attribute [r] name
    #   @api public
    #   @return [String] the attribute name
    attr_reader :name

    # @!attribute [r] baseline_value
    #   @api public
    #   @return [Object] the attribute value in the baseline catalog
    attr_reader :baseline_value

    # @!attribute [r] preview_value
    #   @api public
    #   @return [Object] the attribute value in the preview catalog
    attr_reader :preview_value

    # @!attribute [r] compliant
    #   @api public
    #   @return [Boolean] `true` if the preview value is considered compliant with the baseline value
    attr_reader :compliant

    # @param name [String]
    # @param baseline_value [Object]
    # @param preview_value [Object]
    # @param compliant [Boolean]
   def initialize(name, baseline_value, preview_value, compliant)
      @name = name
      @baseline_value = baseline_value
      @preview_value = preview_value
      @compliant = compliant
    end
  end

  # Represents a resource in the Catalog.
  #
  # @api public
  class Resource < Diff
    # @!attribute [r] location
    #   @api public
    #   @return [Location] the resource location
    attr_reader :location

    # @!attribute [r] type
    #   @api public
    #   @return [String] the resource type
    attr_reader :type

    # @!attribute [r] title
    #   @api public
    #   @return [String] the resource title
    attr_reader :title

    # @!attribute [r] attributes
    #   The attribute array will be `nil` when the delta was produced in non-verbose mode
    #
    #   @api public
    #   @return [Array<Attribute>,nil] the attributes of this resource
    attr_reader :attributes

    # @param location [Location]
    # @param type [String]
    # @param title [String]
    # @param attributes [Array<Attribute>]
    def initialize(location, type, title, attributes)
      @location = location
      @type = type
      @title = title
      @attributes = attributes
    end

    # Returns the key that uniquely identifies the Resource. The key is used when finding
    # added, missing, equal, and conflicting resources in the compared catalogs.
    #
    # @return [String] resource key constructed from type and title
    # @api public
    def key
      "#{@type}{#{@title}}]"
    end

    def assign_ids(start)
      assign_ids_on_each(super(start), attributes)
    end

    # Set the _attributes_ instance variable to `nil`. This is done for all resources
    # in the delta unless the production is flagged as verbose
    #
    # @api private
    def clear_attributes
      @attributes = nil
    end
  end

  # Represents a resource conflict between a resource in the baseline and a resource with the
  # same type and title in the preview
  #
  # @api public
  class ResourceConflict < Diff
    # @!attribute [r] baseline_location
    #   @api public
    #   @return [Location] the baseline resource location
    attr_reader :baseline_location

    # @!attribute [r] preview_location
    #   @api public
    #   @return [Location] the preview resource location
    attr_reader :preview_location

    # @!attribute [r] type
    #   @api public
    #   @return [String] the resource type
    attr_reader :type

    # @!attribute [r] title
    #   @api public
    #   @return [String] the resource title
    attr_reader :title

    # @!attribute [r] added_attributes
    #   @api public
    #   @return [Array<Attribute>] attributes added in preview resource
    attr_reader :added_attributes

    # @!attribute [r] missing_attributes
    #   @api public
    #   @return [Array<Attribute>] attributes only present in baseline resource
    attr_reader :missing_attributes

    # @!attribute [r] conflicting_attributes
    #   @api public
    #   @return [Array<AttributeConflict>] attributes that are in conflict between baseline and preview
    attr_reader :conflicting_attributes

    # @!attribute [r] equal_attribute_count
    #   @api public
    #   @return [Integer] number of equal attributes
    attr_reader :equal_attribute_count

    # @!attribute [r] added_attribute_count
    #   @api public
    #   @return [Integer] number of added attributes
    attr_reader :added_attribute_count

    # @!attribute [r] missing_attribute_count
    #   @api public
    #   @return [Integer] number of missing attributes
    attr_reader :missing_attribute_count

    # @!attribute [r] conflicting_attribute_count
    #   @api public
    #   @return [Integer] number of conflicting attributes
    attr_reader :conflicting_attribute_count

    # @param baseline_location [Location]
    # @param preview_location [Location]
    # @param type [String]
    # @param title [String]
    # @param equal_attribute_count [Integer]
    # @param added_attributes [Array<Attribute>]
    # @param missing_attributes [Array<Attribute>]
    # @param conflicting_attributes [Array<AttributeConfict>]
    def initialize(baseline_location, preview_location, type, title, equal_attribute_count, added_attributes, missing_attributes, conflicting_attributes)
      @baseline_location = baseline_location
      @preview_location = preview_location
      @type = type
      @title = title
      @equal_attribute_count = equal_attribute_count
      @added_attributes = added_attributes
      @added_attribute_count = added_attributes.size
      @missing_attributes = missing_attributes
      @missing_attribute_count = missing_attributes.size
      @conflicting_attributes = conflicting_attributes
      @conflicting_attribute_count = conflicting_attributes.size
    end

    def assign_ids(start)
      start = super
      start = assign_ids_on_each(start, added_attributes)
      start = assign_ids_on_each(start, missing_attributes)
      start = assign_ids_on_each(start, conflicting_attributes)
      start
    end
  end

  # Represents a delta between two catalogs
  #
  # @api public
  class CatalogDelta < Diff
    # @!attribute [r] baseline_env
    #   @api public
    #   @return [String] name of baseline environment
    attr_reader :baseline_env

    # @!attribute [r] preview_env
    #   @api public
    #   @return [String] name of preview environment
    attr_reader :preview_env

    # @!attribute [r] tags_ignored
    #   @api public
    #   @return [Boolean] `true` if tags are ignored when comparing resources
    attr_reader :tags_ignored

    # @!attribute [r] preview_compliant
    #   @api public
    #   @return [Boolean] `true` if preview is compliant with baseline
    attr_reader :preview_compliant

    # @!attribute [r] preview_equal
    #   @api public
    #   @return [Boolean] `true` if preview is equal to baseline
    attr_reader :preview_equal

    # @!attribute [r] preview_equal
    #   @api public
    #   @return [Boolean] `true` if baseline version is equal to preview version
    attr_reader :version_equal

    # @!attribute [r] baseline_resource_count
    #   @api public
    #   @return [Integer] number of resources in baseline
    attr_reader :baseline_resource_count

    # @!attribute [r] preview_resource_count
    #   @api public
    #   @return [Integer] number of resources in preview
    attr_reader :preview_resource_count

    # @!attribute [r] added_resource_count
    #   @api public
    #   @return [Integer] number of resources added in preview
    attr_reader :added_resource_count

    # @!attribute [r] missing_resource_count
    #   @api public
    #   @return [Integer] number of resources only present in baseline
    attr_reader :missing_resource_count

    # @!attribute [r] conflicting_resource_count
    #   @api public
    #   @return [Integer] number of resources in conflict between baseline and preview
    attr_reader :conflicting_resource_count

    # @!attribute [r] added_edge_count
    #   @api public
    #   @return [Integer] number of edges added in preview
    attr_reader :added_edge_count

    # @!attribute [r] missing_edge_count
    #   @api public
    #   @return [Integer] number of edges only present in baseline
    attr_reader :missing_edge_count

    # @!attribute [r] added_resource_count
    #   @api public
    #   @return [Integer] total number of resource attributes added in preview
    attr_reader :added_attribute_count

    # @!attribute [r] missing_resource_count
    #   @api public
    #   @return [Integer] total number of resource attributes only present in baseline
    attr_reader :missing_attribute_count

    # @!attribute [r] conflicting_resource_count
    #   @api public
    #   @return [Integer] total number of resource attributes in conflict between baseline and preview
    attr_reader :conflicting_attribute_count

    # @!attribute [r] baseline_edge_count
    #   @api public
    #   @return [Integer] number of edges in baseline
    attr_reader :baseline_edge_count

    # @!attribute [r] preview_edge_count
    #   @api public
    #   @return [Integer] number of edges in preview
    attr_reader :preview_edge_count

    # @!attribute [r] missing_resources
    #   @api public
    #   @return [Array<Resource>] resources only present in baseline
    attr_reader :missing_resources

    # @!attribute [r] added_resources
    #   @api public
    #   @return [Array<Resource>] resources added in preview
    attr_reader :added_resources

    # @!attribute [r] conflicting_resources
    #   @api public
    #   @return [Array<ResourceConflict>] resources in conflict between baseline and preview
    attr_reader :conflicting_resources

    # @!attribute [r] missing_edges
    #   @api public
    #   @return [Array<Edge>] edges only present in baseline
    attr_reader :missing_edges

    # @!attribute [r] added_edges
    #   @api public
    #   @return [Array<Edge>] edges added in preview
    attr_reader :added_edges

    # Creates a new delta between the two catalog hashes _baseline_ and _preview_. The delta will be produced
    # without considering differences in resource tagging if _ignore_tags_ is set to `true`. The _verbose_
    # flag controls wether or not attributes will be included in missing and added resources in the delta.
    #
    # @param baseline [Hash<Symbol,Object>] the hash representing the baseline catalog
    # @param preview [Hash<Symbol,Object] the hash representing the preview catalog
    # @param ignore_tags [Boolean] `true` if tags should be ingored when comparing resources
    # @param verbose [Boolean] `true` to include attributes of missing and added resources in the delta
    #
    # @api public
    def initialize(baseline, preview, ignore_tags, verbose)
      baseline = assert_type(Hash, baseline, {})
      preview = assert_type(Hash, preview, {})

      @baseline_env = baseline['environment']
      @preview_env = preview['environment']
      @tags_ignored = ignore_tags
      @version_equal = baseline['version'] == preview['version']

      baseline_resources = create_resources(baseline)
      @baseline_resource_count = baseline_resources.size


      preview_resources = create_resources(preview)
      @preview_resource_count = preview_resources.size

      @added_resources = preview_resources.reject { |key,_| baseline_resources.include?(key) }.values
      @added_resource_count = @added_resources.size
      @added_attribute_count = @added_resources.inject(0) { |count, r| count + r.attributes.size }

      @missing_resources = baseline_resources.reject { |key,_| preview_resources.include?(key) }.values
      @missing_resource_count = @missing_resources.size
      @missing_attribute_count = @missing_resources.inject(0) { |count, r| count + r.attributes.size }

      @equal_resource_count = 0
      @equal_attribute_count = 0
      @conflicting_attribute_count = 0

      @conflicting_resources = []
      baseline_resources.each_pair do |key,br|
        pr = preview_resources[key]
        next if pr.nil?
        conflict = create_resource_conflict(br, pr, ignore_tags)
        if conflict.nil?
          # Resources are equal
          @equal_resource_count += 1
          @equal_attribute_count += br.attributes.size
        else
          @conflicting_resources << conflict
          @equal_attribute_count += conflict.equal_attribute_count
          @conflicting_attribute_count += conflict.conflicting_attributes.size
          @added_attribute_count += conflict.added_attributes.size
          @missing_attribute_count += conflict.missing_attributes.size
        end
      end
      @conflicting_resource_count = @conflicting_resources.size

      baseline_edges = create_edges(baseline)
      @baseline_edge_count = baseline_edges.size

      preview_edges = create_edges(preview)
      @preview_edge_count = preview_edges.size

      @added_edges = preview_edges.reject { |edge| baseline_edges.include?(edge) }
      @added_edge_count = @added_edges.size
      @missing_edges = baseline_edges.reject { |edge| preview_edges.include?(edge) }
      @missing_edge_count = @missing_edges.size

      @preview_compliant = @missing_resources.empty? && @conflicting_resources.empty? && @missing_edges.empty?
      @preview_equal = @preview_compliant && @added_resources.empty? && @added_edges.empty?

      unless verbose
        # Clear attributes in the added and missing resources array
        @added_resources.each { |r| r.clear_attributes }
        @missing_resources.each { |r| r.clear_attributes }
      end

      assign_ids(1)
    end

    def assign_ids(start)
      start = super
      start = assign_ids_on_each(start, added_resources)
      start = assign_ids_on_each(start, missing_resources)
      start = assign_ids_on_each(start, conflicting_resources)
      start = assign_ids_on_each(start, added_edges)
      start = assign_ids_on_each(start, missing_edges)
      start
    end

    # @param br [Resource] Baseline resource
    # @param pr [Resource] Preview resource
    # @return [ResourceConflict]
    # @api private
    def create_resource_conflict(br, pr, ignore_tags)
      added_attributes = pr.attributes.reject { |key, a| br.attributes.include?(key) }
      missing_attributes = br.attributes.reject { |key, a| pr.attributes.include?(key) }
      conflicting_attributes = []
      br.attributes.each_pair do |key,ba|
        pa = pr.attributes[key]
        next if pa.nil? || ignore_tags && key == 'tags'
        conflict = create_attribute_conflict(ba, pa)
        conflicting_attributes << conflict unless conflict.nil?
      end
      if added_attributes.empty? && missing_attributes.empty? && conflicting_attributes.empty?
        nil
      else
        equal_attributes_count = br.attributes.size - conflicting_attributes.size
        ResourceConflict.new(br.location, pr.location, br.type, br.title, equal_attributes_count, added_attributes, missing_attributes, conflicting_attributes)
      end
    end
    private :create_resource_conflict

    # @param ba [Attribute]
    # @param pa [Attribute]
    # @return [AttributeConflict,nil]
    # @api private
    def create_attribute_conflict(ba, pa)
      bav = ba.value
      pav = pa.value
      bav == pav ? nil : AttributeConflict.new(ba.name, bav, pav, compliant?(bav, pav))
    end
    private :create_attribute_conflict

    # Answers the question, is _bav_ and _pav_ compliant?
    # Sets are compliant if _pav_ is a subset of _bav_
    # Arrays are compliant if _pav_ contains all non unique values in _bav_. Order is insigificant
    # Hashes are compliant if _pav_ has at least the same set of keys as _bav_, and the values are compliant
    # All other values are compliant if the values are equal
    #
    # @param bav [Object] value of baseline attribute
    # @param pav [Object] value of preview attribute
    # @return [Boolean] the result of the comparison
    # @api private
    def compliant?(bav, pav)
      if bav.is_a?(Set) && pav.is_a?(Set)
        ba.subset?(pa)
      elsif bav.is_a?(Array) && pav.is_a?(Array)
        bav.all? { |e| pav.include?(e) }
      elsif bav.is_a?(Hash) && pav.is_a?(Hash)
        # Double negation here since Hash doesn't have an all? method
        !bav.any? {|k,v| !(pav.include?(k) && compliant?(v, pav[k])) }
      else
        bav == pav
      end
    end

    # @param hash [Hash] a Catalog hash
    # @return [Hash<String,Resource>] a Hash of Resource objects keyed by the Resource#key
    # @api private
    def create_resources(hash)
      result = {}
      assert_type(Array, hash['resources'], []).each do |rh|
        resource = create_resource(rh)
        result[resource.key] = resource
      end
      result
    end
    private :create_resources

    # @param resource [Hash] a Resource hash
    # @param verbose [Boolean]
    # @return [Resource]
    # @api private
    def create_resource(resource)
      Resource.new(create_location(resource), assert_type(String, resource['type']), assert_type(String, resource['title']), create_attributes(resource))
    end
    private :create_resource

    # @param hash [Hash] a Catalog hash
    # @return [Array<Edge>]
    # @api private
    def create_edges(hash)
      assert_type(Array, hash['edges'], []).map { |eh| resource = create_edge(assert_type(Hash, eh, {})) }
    end
    private :create_edges

    # @param hash [Hash] an Edge hash
    # @return [Edge]
    # @api private
    def create_edge(hash)
      Edge.new(assert_type(String, hash['source']), assert_type(String, hash['target']))
    end
    private :create_edge

    # @param elem [Hash] a Location hash
    # @return [Location]
    # @api private
    def create_location(elem)
      file = assert_type(String, elem['file'])
      line = assert_type(Integer, elem['line'])
      file.nil? && line.nil? ? nil : Location.new(file, line)
    end
    private :create_location

    # @param resource [Array<Hash>] a Resource hash
    # @return [Hash<String,Attribute>]
    # @api private
    def create_attributes(resource)
      attrs = {}
      attrs['tags'] = create_attribute('tags', assert_type(Array, resource['tags'], []))
      attrs['@@'] = create_attribute('@@', assert_boolean(resource['exported'], false))
      assert_type(Hash, resource['parameters'], {}).each_pair { |name, value| attrs[name] = create_attribute(name, value)}
      attrs
    end
    private :create_attributes

    # @param name [String]
    # @param value [Object]
    # @api private
    def create_attribute(name, value)
      value = Set.new(assert_type(Array, value, [])) if %w(before, after, subscribe, notify, tags).include?(name)
      Attribute.new(name, value)
    end
    private :create_attribute
  end
end