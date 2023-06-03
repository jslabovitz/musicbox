class MusicBox

  class Listen < Simple::Group::Item

    attr_accessor :listened_at
    attr_accessor :artist_name
    attr_accessor :album_title
    attr_accessor :album_id
    attr_accessor :track_title
    attr_accessor :track_num
    attr_accessor :track_disc

    include Simple::Printer::Printable

    def initialize(**params)
      super
    end

    def inspect
      "<#{self.class}>"
    end

    def to_h
      super.merge(
        listened_at: @listened_at,
        artist_name: @artist_name,
        album_title: @album_title,
        album_id: @album_id,
        track_title: @track_title,
        track_num: @track_num,
        track_disc: @track_disc,
      )
    end

  end

end