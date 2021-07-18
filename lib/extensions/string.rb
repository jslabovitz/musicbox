class String

  IgnoredWords = %w{
    a
    an
    and
    but
    de
    des
    for
    from
    le
    les
    of
    on
    or
    the
    to
  }

  def normalize
    downcase.                     # lowercase
      unaccent.                   # 'normalize' accents
      delete(%q{'"‘’“”}).         # remove quotes
      sub(/\(.*?\)/, '').         # remove parenthetical text
      gsub(/[^a-z0-9]+/, ' ').    # convert non-alphanumeric to whitespace
      strip.squeeze(' ')          # compress/remove whitespace
  end

  def tokenize
    words = normalize.split(/\s+/)
    new_words = words - IgnoredWords
    new_words.empty? ? words : new_words    # handles 'The The', etc.
  end

end