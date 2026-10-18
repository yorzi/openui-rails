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

      test "renders the pinned runtime attributes" do
        html = openui_surface(id: "s1", version: 1)

        assert_includes html, 'data-openui-runtime-url="/openui/openui-browser-bundle-0.2.1.js"'
        assert_includes html, 'data-openui-runtime-version="0.2.1"'
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

      test "marks a settled surface as not busy for assistive tech" do
        html = openui_surface(id: "s1", version: 1)

        assert_includes html, 'aria-busy="false"'
        refute_includes html, 'role="region"'
      end

      test "marks a streaming surface as busy" do
        html = openui_surface(id: "s1", version: 1, stream: true)

        assert_includes html, 'aria-busy="true"'
      end

      test "exposes a labelled surface as a named region" do
        html = openui_surface(id: "s1", version: 1, label: "Order details")

        assert_includes html, 'role="region"'
        assert_includes html, 'aria-label="Order details"'
      end

      test "refuses a persisted surface from an incompatible library" do
        previous = OpenUI::Rails.configuration.library_spec_path
        OpenUI::Rails.configure { |config| config.library_spec_path = file_fixture("library.spec.json") }
        assert_raises(LibraryVersionError) { openui_surface(id: "s1", library_version: "sha256:wrong") }
      ensure
        OpenUI::Rails.configure { |config| config.library_spec_path = previous }
      end
    end
  end
end
