require 'application_system_test_case'

class InstallTest < ApplicationSystemTestCase
  test 'install button stays hidden with no beforeinstallprompt event' do
    visit root_path

    assert_selector 'button[title="Install Dink Pony Club"]', visible: false
    assert_no_selector 'button[title="Install Dink Pony Club"]', visible: true
  end

  test 'install button appears, prompts, and hides after a synthetic beforeinstallprompt' do
    visit root_path

    page.execute_script(<<~JS)
      const event = new Event("beforeinstallprompt")
      event.prompt = () => { window.dpcPromptCalled = true; return Promise.resolve() }
      window.dispatchEvent(event)
    JS

    assert_selector 'button[title="Install Dink Pony Club"]', visible: true

    find('button[title="Install Dink Pony Club"]').click

    assert page.evaluate_script('window.dpcPromptCalled')
    assert_no_selector 'button[title="Install Dink Pony Club"]', visible: true
  end
end
