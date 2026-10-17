# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    class ViewHelperTest < ActionView::TestCase
      include OpenUI::Rails::ViewHelper

      test "renders an escaped mount element" do
        html = openui_surface(id: "s1", version: 1, library_version: "sha256:x", response: "root = Card()")

        assert_includes html, 'data-controller="openui"'
        assert_includes html, 'data-openui-surface-id="s1"'
        assert_includes html, 'data-openui-version="1"'
        assert_includes html, 'data-openui-library-version="sha256:x"'
        assert_includes html, 'class="openui-surface"'
        assert_includes html, 'id="openui-surface-s1"'
      end

      test "escapes values that could break out of the attribute" do
        html = openui_surface(id: "s1", response: %q{root = TextContent("</div><script>alert(1)</script>")})

        refute_includes html, "<script>alert(1)</script>"
        assert_includes html, "&lt;script&gt;"
      end

      test "honours an explicit dom id" do
        html = openui_surface(surface: { id: "s1" }, dom_id: "custom-mount")

        assert_includes html, 'id="custom-mount"'
      end
    end
  end
end
