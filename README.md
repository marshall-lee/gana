[![Build Status](https://travis-ci.org/marshall-lee/gana.svg?branch=master)](https://travis-ci.org/marshall-lee/gana)

# Gana

## Installation

Create a new playground:

```
$ mkdir gana_ground
$ cd gana_ground
$ bundle init
```

Add this lines to your playground's Gemfile:

```ruby
gem 'gana'
gem 'curses
```

And then execute:

    $ bundle install
    
# Usage

Minimal gana script looks like this:

```ruby
gana do |t1,t2|
  # ...
end
```

Save it to `sample.rb` and then you can run it:

```
gana sample.rb
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marshall-lee/gana.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
