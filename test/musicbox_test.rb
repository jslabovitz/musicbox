require 'minitest/autorun'
require 'minitest/power_assert'

require 'musicbox'

class MusicBox

  class Test < Minitest::Test

    def setup
      @musicbox = MusicBox.new
    end

    def test_tracks
      albums = @musicbox.find_albums
      assert { albums.count != 0 }
    end

  end

end