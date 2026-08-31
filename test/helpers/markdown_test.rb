require "test_helper"

class MarkdownTest < ActionView::TestCase
  include ApplicationHelper

  test "renders headings and nested lists" do
    html = markdown("## Plan\n\n- Sat 5 - leave for Kamloops\n- Sun 6 - catch 1pm ferry\n")
    assert_match(/<h2>Plan<\/h2>/, html)
    assert_equal 2, html.scan("<li>").size
  end

  test "blank notes render nothing" do
    assert_nil markdown(nil)
    assert_nil markdown("  ")
  end

  test "strips script from note text rather than rendering it" do
    html = markdown("Hi\n\n<script>alert(1)</script>\n")
    assert_no_match(/<script/, html)
  end

  test "keeps a plain apostrophe readable" do
    assert_match(/Nancy/, markdown("Nancy's Bakery"))
  end

  test "a heading straight after another block still renders as a heading" do
    # People don't leave blank lines between sections; strict kramdown would
    # render this one as literal "#### BC Ferries" text.
    html = markdown("### Details\n#### BC Ferries - booked\n- 31 feet\n")
    assert_match(/<h4>BC Ferries - booked<\/h4>/, html)
    assert_match(/<li>31 feet<\/li>/, html)
  end

  test "measurements keep straight quotes rather than being curled" do
    html = markdown(%q(Trailer is 14' long and 6'7" high))
    assert_includes html, "14' long"
    assert_includes html, %q(6'7" high)
    assert_no_match(/[\u2018\u2019\u201c\u201d]/, html)
  end
end
