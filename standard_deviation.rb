module Enumerable
  def sum(&blk)
    map(&blk).reduce(0) { |sum, element| sum + element }
  end

  def mean
    sum.to_f / size
  end

  def variance
    _mean = mean
    sum { |i| (i - _mean) ** 2 } / size
  end

  def std_dev
    Math.sqrt variance
  end

  def z_scores
    _mean, _std_dev = mean, std_dev
    map { |e| (e - _mean) / _std_dev }
  end

  def scale(range)
    set_max, range_max = max, range.max
    map { |x| x / (set_max / range_max) }
  end
end

module StandardDeviation
  DECILE_BINS = [
    -Float::INFINITY,
    -1.208,
    -0.804,
    -0.502,
    -0.205,
     0.0,
     0.206,
     0.503,
     0.805,
     1.209,
     Float::INFINITY
  ]

  def self.decile(z_score)
    DECILE_BINS.each_with_index { |bin, index| return index if z_score < bin }
  end
end

if $0 == __FILE__
  require 'test/unit'
  class StatsTest < Test::Unit::TestCase
    DOLLARS = %w(
     3013393.3
     3214426.6
     4848175.54
     14564528.09
     3755073.93
     715109.27
     17574128.24
     4264381.68
     15371827.25
     201833.49
     309141.95
     857273.75
     6812680.36
     60268.74
     1893672.23
     26301374.45
     630276.71
     2046414.79
     213316.59
     2435571.19
     4279765.58
     453878.13
     3159793.79
     788693.1
     3964048.29
     3827491.3
     3293435.84
    ).map(&:to_f)

    def test_scale
      assert_equal true, [].respond_to?(:scale)
      assert_equal [1, 2, 4, 10], [3, 6, 12, 30].scale(1..10)
      assert_equal [0, 1, 1, 2], [50, 100, 150, 200].scale(1..2)
    end

    def test_std_dev
      set = [1, 4, 5, 10, 20]
      assert_equal 8, set.mean
      assert_equal 44.4, set.variance
      assert_equal 6.663332499583072, set.std_dev
      assert_equal [2, 3, 4, 7, 10], set.z_scores.map { |i| StandardDeviation.decile(i) }
      assert_equal 38578514821880.5, DOLLARS.variance
    end
  end
end
