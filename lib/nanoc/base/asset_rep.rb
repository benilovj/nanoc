module Nanoc

  class AssetRep

    attr_reader :asset

    attr_reader :attributes

    attr_reader :name

    def initialize(asset, attributes, name)
      # Set primary attributes
      @asset            = asset
      @attributes       = attributes
      @name             = name

      # Compiled file is not present
      @uncompiled_file  = asset.file
      @compiled_file    = nil

      # Not modified, not created by default
      @modified         = false
      @created          = false

      # Reset flags
      @filtered         = false
      @written          = false
    end

    def to_proxy
      @proxy ||= AssetRepProxy.new(self)
    end

    # Returns true if this asset rep's output file was created during the last
    # compilation session, or false if the output file did already exist.
    def created?
      @created
    end

    # Returns true if this asset rep's output file was modified during the
    # last compilation session, or false if the output file wasn't changed.
    def modified?
      @modified
    end

    # Returns the path to the output file, including the path to the output
    # directory specified in the site configuration, and including the
    # filename and extension.
    def disk_path
      @disk_path ||= @asset.site.router.disk_path_for(self)
    end

    # Returns the path to the output file as it would be used in a web
    # browser: starting with a slash (representing the web root), and only
    # including the filename and extension if they cannot be ignored (i.e.
    # they are not in the site configuration's list of index files).
    def web_path
      @web_path ||= @asset.site.router.web_path_for(self)
    end

    def outdated?
      # Outdated if compiled file doesn't exist
      return true if !File.file?(disk_path)

      # Get compiled mtime
      compiled_mtime = File.stat(disk_path).mtime

      # Outdated if file too old
      return true if @asset.mtime > compiled_mtime

      # Outdated if dependencies outdated
      # FIXME re-enable
      #return true if @asset.site.asset_defaults.mtime and @asset.site.asset__defaults.mtime > compiled_mtime
      return true if @asset.site.code.mtime and @asset.site.code.mtime > compiled_mtime

      return false
    end

    # Returns the attribute with the given name. This method will look in
    # several places for the requested attribute:
    #
    # 1. This asset representation's attributes;
    # 2. The attributes of this asset representation's asset (but only if this
    #    is the default representation);
    # 3. The asset defaults' representation corresponding to this asset
    #    representation;
    # 4. The asset defaults in general (but only if this is the default asset
    #    representation);
    # 5. The hardcoded asset defaults, if everything else fails.
    def attribute_named(name)
      # Check in here
      return @attributes[name] if @attributes.has_key?(name)

      # Check in asset
      if @name == :default
        return @asset.attributes[name] if @asset.attributes.has_key?(name)
      end

      # TODO Check in asset defaults' asset rep

      # TODO Check in site defaults (global)

      # Check in hardcoded defaults
      return Nanoc::Asset::DEFAULTS[name]
    end

    def compile
      # Get filters
      filters = attribute_named(:filters)

      # Run each filter
      current_file = @uncompiled_file
      filters.each do |filter_name|
        # Create filter
        klass = PluginManager.instance.binary_filter(filter_name.to_sym)
        raise Nanoc::Errors::UnknownFilterError.new(filter_name) if klass.nil?
        filter = klass.new(self.to_proxy, @asset.to_proxy, @asset.site)

        # Run filter
        current_file = filter.run(current_file)
      end

      # Write asset
      FileUtils.cp(current_file.path, disk_path)
    end

  end

end