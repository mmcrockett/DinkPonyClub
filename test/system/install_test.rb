require 'application_system_test_case'

class InstallTest < ApplicationSystemTestCase
  test 'install button stays hidden with no beforeinstallprompt event' do
    # Chrome considers this page installable and fires its own event; swallow
    # it so this test isolates the "nothing has happened yet" state. CDP
    # re-injects this on every future page load in this browser session, not
    # just this test's, so it must be removed before the session is reused -
    # otherwise it swallows the *other* test's synthetic event too.
    script = page.driver.browser.execute_cdp('Page.addScriptToEvaluateOnNewDocument', source: <<~JS)
      window.addEventListener('beforeinstallprompt', (e) => e.stopImmediatePropagation())
    JS

    visit root_path

    assert_selector 'button[title="Install Dink Pony Club"]', visible: false
    assert_no_selector 'button[title="Install Dink Pony Club"]', visible: true
  ensure
    if script
      page.driver.browser.execute_cdp('Page.removeScriptToEvaluateOnNewDocument', identifier: script['identifier'])
    end
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
