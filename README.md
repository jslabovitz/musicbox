# MusicBox

MusicBox is an opinionated little music management system. It does the following:

- uses the [Discogs](https://discogs.com) platform as a source of metadata
- stores and plays digital audio files corresponding to the tracks of albums
- manages album cover art, downloading replacement cover images where necessary
- allows manipulating of metadata so audio tracks correspond to the actual release
- prints custom labels for sleeves and cases
- prints covers for CDs that don’t have an insert (ie, digipaks)
- allows extensive searching, not just for artist/titles, but also whether an album is missing cover art, hasn't been ripped, etc.
- stores all data locally, so no internet connection required
- exports to iTunes to be able to sync collection with iPhones, etc.


## Conceptual overview

It will be helpful to understand some basic concepts and common structures used in MusicBox. These concepts guide the forward development of MusicBox, as well as acting as design constraints to keep the scope of MusicBox reasonably limited.


### Collection oriented, album/artist oriented

MusicBox is designed by and for people who collect music, specifically in the form of albums, in a certain sequence as created by the artist and their producers. MusicBox treats an artist's creation of an album as a sacred object. Hence, features generally revolve around working with albums as a whole. While there is the occasional random-shuffle feature, the MusicBox user will find themselves naturally led towards appreciating albums from start to finish.

While MusicBox plays audio files imported into its catalog, it does not leave the physical media behind. Rather, the user is encouraged to maintain an organized library that can be appreciated along with the digital representations.

When maintaining a physical library, one of the challenges is keeping the items well-organized. MusicBox helps by allowing the collector to create adhesive paper labels (printed using a standard label printer) with sufficient information to allow the items to be kept in order, generally by artist and release year.

Artist names is a particularly tricky part of the organizational process. MusicBox's simple but effective identification system generates and uses _artist keys._ These are a short but unique representation of an artist's name that is easily alphabetized. For example, Bruce Springsteen is `SprB`, Modest Mouse is `ModM`, and Parliament is `Par`. Configuration options allow for proper sorting of personal names, as well as aliases.


### Highest quality

While MusicBox is generally agnostic about the source of audio files, it can handle sources that consist of downloaded files, tracks ripped from CD, or digitized from LP or tape. There is no specific limit or constraint to resolution, sample rate, or file format. If you have high quality audio files, and high quality playback equipment, you should be able to utilize the maximum quality.

Furthermore, while listening to music, you can easily specify equalization filters, using sources such as [AutoEq](https://github.com/jaakkopasanen/AutoEq)'s database of neutral headphone adjustment curves.

MusicBox uses the excellent [MPV](https://mpv.io) media player to play audio files. When configured appropriately, MPV can play any audio files that MusicBox can store, in bit-perfect quality.


### Local storage

MusicBox is defiantly non-streaming. All audio files and related metadata reside in a real directory of real files. While these files can easily be synchronized to other devices, there is no use or dependency on cloud-based or proprietary services (besides Discogs; see below). Once MusicBox has the needed metadata, playing albums or tracks requires absolutely no internet connection.

By design, there is little or no functionality commonly found in other platforms and players, such as playlists, favorites, recommendations, popularity lists, lyrics, and so on.

Generally, all data is in open formats, such as JSON and YAML, to encourage the creation of tools to manipulate and maintain data. For example, MusicBox's catalog can easily be version-controlled with [Git](https://git-scm.com).


### Discogs as the 'truth'

Instead of re-inventing the wheel to store the extremely complex schema of music releases, MusicBox delegates most of that to the very competent [Discogs](https://discogs.com) platform. Much work has been done to avoid duplicating Discogs' breadth of data, and instead to use Discogs as the authoritative 'truth' wherever possible.

Discogs has several databases that MusicBox 'borrows' (generally by downloading and caching locally), including:

- _release_ -- Represents a specific issuance of a record, such as a CD or LP. You could call it an 'album,' but in MusicBox, an album is something else (see below).

- _master_ -- Represents more than one version of a release. Not all releases have a master. For example, if a given record is issued only on CD, in a single pressing, there may not be a master. But if the record is issued on vinyl & CD, there will be one _master_ record and two _release_ records.

- _collection_ -- The list of releases actually owned by the user (ie, you). MusicBox generally uses the collection to synchronize associated releases, masters, and artists. If you update your collection on Discogs, you can issue a MusicBox command to download the changed collection, and update the related records.

Data structures in Discogs are identified with an ID, which is an integer. You will sometimes see this shown in MusicBox, and it is useful to identify a specific release, master, or album.

In general, you must keep your Discogs collection updated according to your actual music collection. MusicBox itself has no way of editing your collection; you must edit on Discogs' site, and then update to synchronize. (In the future, MusicBox may support non-released albums -- like personal mixtapes -- but for now, an Discogs account with an accurate collection is required.)


### Albums as 'real' instances

In addition to the Discogs structures described above, MusicBox maintains a database of _albums._ An album can be understood as a specific instance of a release (which may be one of several releases, under a master). In MusicBox, an album is where the actual audio tracks and other associated files are stored. In general, the ID of an album is equal to the ID of its associated release (but this may change).

An album has one or more tracks, which are the actual song files for the release tracks.

Occasionally, the tracks of a digitized album do not match up with the tracks listed under a release. For example, a ripped CD might combine several sub-tracks into a single track. The `import` command allows you to customize the matching between album tracks and release tracks.


### Queries

Most commands support a generalized query language. The simplest form is a series of words, which will search the text of album titles and artists:

```
musicbox show smith
```

Further _selectors_ (prefixed with a colon) modify a query, such as:

- `:recently-added` -- added to collection in last 30 days
- `:cd` -- releases that are in CD format
- `:unripped` -- releases that do not yet have any audio files
- `:no-cover` -- releases without a cover image


### Command-line first

MusicBox is controlled entirely through a command-line interface. The main tool is called `musicbox`, with successive sub-commands to perform certain actions. For example, to play Holger Czukay's [Moving Pictures](https://www.discogs.com/Holger-Czukay-Moving-Pictures/release/159821), applying equalization adjustment for Apple's Beats X headphones:

```
musicbox play --eq='Beats X' 'Moving Pictures'
```

Future versions of MusicBox may incorporate standalone/headless instances, or platform-specific players.


## Installation

- Confirm that you are using a Mac running macOS, preferably with [Homebrew](https://brew.sh) installed and working. Although MusicBox does not explicitly require macOS, there are a few places where other systems will likely break at the moment. MusicBox was developed using Ruby 3.0. It may not be compatible with earlier versions.

- Install required Homebrew packages:

```
brew install mpv mp4v taglib
```

<!--
- Manually install `taglib-ruby` (change `1.12` below to whatever version the previous `brew install` command installed):

```
TAGLIB_DIR=$HOMEBREW_CELLAR/taglib/1.12 gem install taglib-ruby
```
-->

- Install this gem, and dependent gems:

```
gem install musicbox
```

- If you want MusicBox to store its files other than the default location of `~/Music/MusicBox`, then set the `MUSICBOX_ROOT` environment variable in your shell:

```
export MUSICBOX_ROOT=somewhere_else
```

- Create the directory:

```
mkdir ~/Music/MusicBox
```

- Create a Discogs account, if you haven't already, and add at least one release to your collection.

- Create a personal access token on Discogs by going to [this page](https://www.discogs.com/settings/developers) and clicking the blue button labeled 'Generate new token'. Copy the generated token for the next step.

- Create a simple configuration file named `config.yaml` in your main MusicBox directory:

```
# $MUSICBOX_ROOT/config.yaml
user: YOUR_DISCOGS_USERNAME
token: YOUR_DISCOGS_TOKEN
```


## Operation

Here are a few common commands. There are more uncommon commands, as yet undocumented.


### Update your collection

```
musicbox update
```

This will connect to Discogs, download your collection, and download any further information for the releases in your collection.


### Search and show

```
musicbox show [QUERY]
```

This will search your collection for `QUERY` and show them in a summary view. By adding `--details` after `show`, MusicBox will show all the details of the found releases. If no query is specified, all releases are shown.


### Import

```
musicbox import [DIR ...]
```

This will import albums into your catalog. You can specify the directories to import, or create a directory called `import` inside your MusicBox directory containing directories to import.

Each directory should contain an entire album, with each track represented as an `.mp4` file. MusicBox will attempt to find the correct release for the given album, as well as the tracks. If the track info does not line up with the information in the related Discogs release, MusicBox will begin an interactive prompting session. (If this doesn't work, you'll have to edit the JSON file by hand.)


### Export

```
musicbox export --dir=DIR [QUERY]
```

This will export the tracks for the albums of selected releases to the directory `DIR`. Albums will be saved to named subdirectories. By default, tracks are compressed in lossy AAC format; specify `--compress=false` to export tracks in lossless ALAC.


### Make covers and labels

```
musicbox label [QUERY]
musicbox cover [QUERY]
```

This will generate PDF files with labels or cover images, respectively, for the specified releases.

Labels will be formatted for 1x3" (approximately) labels.

Covers are sized as typical CD covers, a bit less than 5" square. Cut with scissors or a sharp knife along the black border lines.

If a cover does not yet exist, one is attempted to be found from the following sources:

- the cover (aka box) image found within the audio track, usually derived from a CD ripping program that looks up releases on a service like CDDB

- the 'primary' or 'secondary' image specified in the Discogs release page or master page

Covers will be displayed, and a prompt will allow selection of the appropriate image.


## Questions? Comments? Suggestions?

Email me at johnl@johnlabovitz.com, or file an issue here.