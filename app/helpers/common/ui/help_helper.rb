module Common::Ui::HelpHelper
  protected

  def formatting_reference_link(options = {})
    options.reverse_merge! class: 'icon help_16',
                           href: '/do/static/greencloth',
                           onclick: 'quickRedReference(); return false;'
    content_tag(:a, options) do
      :formatting_reference_link.t
    end
  end

  # returns the related help string, but only if it is translated.
  def help(symbol)
    symbol = "#{symbol}_help".to_sym
    text = nil
    begin
      text = I18n.t(symbol)
    rescue I18n::MissingTranslationData
      # this error is only raised in dev/test mode when translation is missing
      return nil
    end

    # return nil if I18n.t can't find the translation (in production mode) and has to humanize it
    text == symbol.to_s.humanize ? nil : text.html_safe
  end
end
