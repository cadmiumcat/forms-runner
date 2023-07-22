require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#page_title" do
    it "returns the title with the GOV.UK suffix" do
      helper.set_page_title("Test")
      expect(view.content_for(:title)).to eq("Test")
      expect(helper.page_title).to eq("Test – GOV.UK")
    end
  end

  describe "#question_text_with_optional_suffix" do
    context "with an optional question" do
      it "returns the title with the optional suffix" do
        page = OpenStruct.new(question_text: "What is your name?", question: OpenStruct.new(show_optional_suffix: true))
        mode = OpenStruct.new(preview?: false)
        expect(helper.question_text_with_optional_suffix_inc_mode(page, mode)).to eq("What is your name? #{I18n.t("page.optional")}")
      end
    end

    context "with unsafe question text" do
      it "returns the escaped title with the optional suffix" do
        page = OpenStruct.new(question_text: "What is your name? <script>alert(\"Hi\")</script>", question: OpenStruct.new(show_optional_suffix: false))
        mode = OpenStruct.new(preview?: true, preview_draft?: true)
        expected_output = "What is your name? &lt;script&gt;alert(&quot;Hi&quot;)&lt;/script&gt; <span class='govuk-visually-hidden'>&nbsp;draft preview</span>"
        expect(helper.question_text_with_optional_suffix_inc_mode(page, mode)).to eq(expected_output)
      end
    end

    context "with a required question" do
      it "returns the title with the optional suffix" do
        page = OpenStruct.new(question_text: "What is your name?", question: OpenStruct.new(show_optional_suffix: false))
        mode = OpenStruct.new(preview?: false)
        expect(helper.question_text_with_optional_suffix_inc_mode(page, mode)).to eq("What is your name?")
      end
    end

    context "with preview draft mode" do
      it "returns the title with the optional suffix with visually hidden text" do
        page = OpenStruct.new(question_text: "What is your name?", question: OpenStruct.new(show_optional_suffix: false))
        mode = OpenStruct.new(preview?: true, preview_draft?: true)
        expect(helper.question_text_with_optional_suffix_inc_mode(page, mode)).to eq("What is your name? <span class='govuk-visually-hidden'>&nbsp;draft preview</span>")
      end
    end

    context "with live preview live mode" do
      it "returns the title with the optional suffix with visually hidden text" do
        page = OpenStruct.new(question_text: "What is your name?", question: OpenStruct.new(show_optional_suffix: false))
        mode = OpenStruct.new(preview?: true, preview_live?: true)
        expect(helper.question_text_with_optional_suffix_inc_mode(page, mode)).to eq("What is your name? <span class='govuk-visually-hidden'>&nbsp;live preview</span>")
      end
    end
  end

  describe "#hidden_text_mode" do
    let(:mode) { OpenStruct.new(preview?: false) }

    it "returns empty string by default if not in some preview mode" do
      expect(helper.hidden_text_mode(mode)).to eq ""
    end

    context "when previewing in draft mode" do
      let(:mode) { OpenStruct.new(preview?: true, preview_draft?: true, preview_live?: false) }

      it "returns a visually hidden span with the mode name" do
        expect(helper.hidden_text_mode(mode)).to eq "<span class='govuk-visually-hidden'>&nbsp;draft preview</span>"
      end
    end

    context "when previewing in live mode " do
      let(:mode) { OpenStruct.new(preview?: true, preview_draft?: false, preview_live?: true) }

      it "returns a visually hidden span with the mode name" do
        expect(helper.hidden_text_mode(mode)).to eq "<span class='govuk-visually-hidden'>&nbsp;live preview</span>"
      end
    end
  end

  describe "#form_title" do
    context "when there is no error" do
      context "when in live mode" do
        it "returns the only the page title" do
          mode = OpenStruct.new("live?": true, "preview_draft?": false, "preview_live?": false)
          expect(helper.form_title(form_name: "form-name", page_name: "page title", mode:)).to eq("page title - form-name")
        end
      end

      context "when in preview draft mode" do
        it "returns the page title and mode" do
          mode = OpenStruct.new("live?": false, "preview_draft?": true, "preview_live?": false)
          expect(helper.form_title(form_name: "form-name", page_name: "page title", mode:)).to eq("page title - Draft preview - form-name")
        end
      end

      context "when in preview live mode" do
        it "returns the page title and mode" do
          mode = OpenStruct.new("live?": false, "preview_draft?": false, "preview_live?": true)
          expect(helper.form_title(form_name: "form-name", page_name: "page title", mode:)).to eq("page title - Live preview - form-name")
        end
      end
    end

    context "when an error is present" do
      it "returns page error and page title when in live mode" do
        mode = OpenStruct.new("live?": true, "preview_draft?": false, "preview_live?": false)
        expect(helper.form_title(form_name: "form-name", page_name: "page title", mode:, error: true)).to eq("Error: page title - form-name")
      end

      it "returns the error, page title and mode when in preview draft mode" do
        mode = OpenStruct.new("live?": false, "preview_draft?": true, "preview_live?": false)
        expect(helper.form_title(form_name: "form-name", page_name: "page title", mode:, error: true)).to eq("Error: page title - Draft preview - form-name")
      end

      it "returns the error, page title and mode when in preview live mode" do
        mode = OpenStruct.new("live?": false, "preview_draft?": false, "preview_live?": true)
        expect(helper.form_title(form_name: "form-name", page_name: "page title", mode:, error: true)).to eq("Error: page title - Live preview - form-name")
      end
    end
  end
end
