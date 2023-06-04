class MusicBox

  class Player

    class Playlists < Simple::Group

      def self.item_class
        Playlist
      end

    end

  end

end