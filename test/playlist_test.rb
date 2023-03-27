require 'minitest/autorun'
require 'minitest/power_assert'

require 'musicbox'

class MusicBox

  class PlaylistTest < MiniTest::Test

    def setup
      @musicbox = MusicBox.new
      @playlist = @musicbox.collection.playlist_for_random_tracks(id: 'test', number: 5)
    end

    def test_tracks
      assert { @playlist.tracks.length == 5 }
    end

    def test_current_track
      @playlist.pos = 0
      assert { @playlist.current_track == @playlist.tracks[0] }
    end

  end

end