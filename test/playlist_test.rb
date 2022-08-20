require 'minitest/autorun'
require 'minitest/power_assert'

require 'musicbox'

class MusicBox

  class PlaylistTest < MiniTest::Test

    def setup
      @playlists = Playlists.new(root: 'test/tmp/playlists')
      @playlist = Playlist.playlist_for_random_tracks(id: 'test', number: 5)
      @playlist.pos = 0
      @playlists.save_item(@playlist)
    end

    def test_save_load
      playlists2 = Playlists.new(root: 'test/tmp/playlists')
      playlist2 = playlists2[@playlist.id]
      assert { @playlist.id == playlist2.id }
    end

    def test_tracks
      assert { @playlist.tracks.length == 5 }
      assert { @playlist.tracks[0].mb_trackid =~ /[\-a-f0-9]+/ }
    end

    def test_current
      assert { @playlist.current_track == @playlist.tracks[0] }
    end

    def test_random_album
      playlist = Playlist.playlist_for_random_album(id: 'album')
      assert { playlist.tracks.length != 0 }
      assert { playlist.tracks.map(&:mb_albumid).uniq.length == 1 }
    end

    def test_album_of_current_track
      playlist2 = @playlist.playlist_for_album_of_current_track(id: 'album2')
      assert { playlist2.tracks.first.mb_albumid == @playlist.current_track.mb_albumid }
      assert { playlist2.tracks.length != 0 }
      assert { playlist2.tracks.map(&:mb_albumid).uniq.length == 1 }
    end

    def test_current_track
      current_track = @playlist.current_track
      assert { current_track }
    end

  end

end