class MusicBox

  module Beets

    ExportMap = {
      :track => :track_num,
      :tracktotal => :track_count,
      :title => nil,
      :album => nil,
      :artist => nil,
      :albumartist => :album_artist,
      :artpath => :cover,
      :path => nil,
      :mb_trackid => nil,
      :mb_albumid => nil,
    }

    def self.import(dir)
      run_beet('import', dir,
        incremental: nil,
        interactive: true)
    end

    def self.random(fields:, album: false, number: nil, time: nil)
      raise Error, "Must specify either number: or time:" if [number, time].compact.length != 1
      params = {
        equal_chance: nil,
        format: format_for_fields(fields),
      }
      params[:album] = nil if album
      params[:number] = number if number
      params[:time] = time if time
      response = run_beet('random', **params)
      unpack_response(response, fields)
    end

    def self.export(query)
      response = run_beet('export', query,
        library: nil,
        include_keys: ExportMap.keys.join(','))
      JSON.parse(response).map do |h|
        HashStruct.new(
          h.to_h { |k, v| export_field_map(k, v) }
        )
      end
    end

    def self.export_field_map(k, v)
      [
        ExportMap[k.to_sym] || k,
        (v =~ /^0\d+$/) ? v.to_s.sub(/^0\d?=$/, '').to_i : v,
      ]
    end

    def self.format_for_fields(fields)
      fields.map { |f| "$#{f}" }.join("\t")
    end

    def self.unpack_response(response, fields)
      response.split("\n").map { |r| r.split("\t") }.map do |rec|
        HashStruct.new(fields.each_with_index.to_h { |k, i| [k, rec[i]] })
      end
    end

    def self.run_beet(sub_command, *args, **params)
      interactive = params.delete(:interactive)
      run_command(
        'beet',
        sub_command,
        params.map { |k, v|
          "--#{k.to_s.gsub('_', '-')}" + (v.nil? ? '' : "=#{v}")
        },
        args,
        interactive: interactive,
        verbose: false)
    end

  end

end