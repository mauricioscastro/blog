# Title: Dynamic directories for Jekyll
# Author: Tommy Sullivan http://superawesometommy.com, Robert Park http://exolucere.ca
# Description: The directory tag lets you iterate over files at a particular path. If files conform to the standard Jekyll format, YYYY-MM-DD-file-title, then those attributes will be populated on the yielded file object. The `forloop` object maintains [its usual context](http://wiki.shopify.com/UsingLiquid#For_loops).
# 
# changed by mauricioscastro@hotmail.com to include mtime instead of ctime and size 
#
# Syntax:
#
#   {% directory path: path/from/source [reverse] [exclude] %}
#     {{ file.url }}
#     {{ file.name }}
#     {{ file.date }}
#     {{ file.slug }}
#     {{ file.title }}
#   {% enddirectory %}
#
# Options:
#
# - `reverse` - Defaults to 'false', ordering files the same way `ls` does: 0-9A-Za-z.
# - `exclude` - Defaults to '.html$', a Regexp of files to skip.
#
# File Attributes:
#
# - `url` - The absolute path to the published file
# - `name` - The basename
# - `date` - The date extracted from the filename, otherwise the file's creation time
# - `slug` - The basename with date and extension removed
# - `title` - The titlecase'd slug
#

module Jekyll

  class DirectoryTag < Liquid::Block
    include Convertible

    STANDARD_POST_FILENAME_MATCHER = /^(.+\/)*(\d+-\d+-\d+)-(.*)(\.[^.]+)$/

    def initialize(tag_name, markup, parse_context)
      super

      @attributes = {}

      markup.scan(Liquid::TagAttributes) do |key, value|
        @attributes[key] = value
      end

      @exclude = Regexp.new(@attributes['exclude'] || '.html$', Regexp::EXTENDED | Regexp::IGNORECASE)
      @reverse = @attributes['reverse'].nil?
    end

    def render(context)
      context.registers[:directory] ||= Hash.new(0)

      path = Liquid::VariableLookup.new(@attributes['path']).evaluate(context)
      path ||= @attributes.fetch('path', '.')
      path = path.gsub(/^\/?(.*)$/,'\1')

      source_dir = context.registers[:site].source
      listed_dir = File.expand_path(File.join(source_dir, path))

      unless listed_dir.include?(source_dir)
        raise Liquid::ArgumentError.new "Listed directory '#{listed_dir}' cannot be out of jekyll root"
      end

      directory_files = File.join(listed_dir, "*")
      files = Dir.glob(directory_files).reject{|f| f =~ @exclude }
      files.sort! {|x,y| @reverse ? x <=> y : y <=> x }

      length = files.length
      result = []

      context.stack do
        files.each_with_index do |filename, index|
          basename = File.basename(filename)

          url = filename.dup
          url.slice!(source_dir)
          
          size_scale = " B"
          size_format = "%d"
          size = File.size(filename)
          
          if size > 1024 and size <= 1024*1024
            size /= 1024.0
            size_scale = " KiB"
            size_format = "%.1f"
          end

          if size > 1024*1024
            size /= 1024.0*1024.0
            size_scale = " MiB"
            size_format = "%.1f"
          end

          m, cats, date, slug, ext = *basename.match(STANDARD_POST_FILENAME_MATCHER)

          if m
            ext = ext
            slug = slug
          else
            ext = File.extname(basename)
            slug = ext ? basename.sub(ext, '') : basename
          end

          context['file'] = {
            'date' => File.mtime(filename),
            'name' => basename,
            'ext' => ext,
            'slug' => slug,
            'url' => url,
            'size' => size_format % size + size_scale
          }

          context['forloop'] = {
            'name' => 'directory',
            'length' => length,
            'index' => index + 1,
            'index0' => index,
            'rindex' => length - index,
            'rindex0' => length - index - 1,
            'first' => (index == 0),
            'last' => (index == length - 1)
          }

          result << nodelist.map{|n|
            if n.respond_to? :render
              n.render(context)
            else
              n
            end
          }.join("")
        end
      end
      result
    end

  end

end

Liquid::Template.register_tag('directory', Jekyll::DirectoryTag)
