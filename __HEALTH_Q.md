calendar


Let's update the wscourge@gmail.com (mine) user's seed to reflect some real-life data. Add a few health events:
- surgery: lasec eyes correction 2021-06-02
- surgery: mole removal, abdomen left side, 2021-12-13
- vaccine: covid, Janssen, 2022-04-26
- injury: left shoulder during bouldering, 5 weeks full recovery, 2025-11-27
- injury: right hand ring finger during bouldering, 6 weeks full recovery, 2024-11-26
Chronic conditions:
- acne-like skin issues on the back, the most at the liver area, since 2012-01-01
- excessive sweating, since 2012-01-01

update new health event page:
1. event type vaccines should alsho have the "Missing vaccine option? Suggest it" functionality
2. event type select option should have their associated icons
3. selecting a new event type should clear the name input
4. after the missing option is submitted it needs to be selected by default as a name, and later returned as a "pending review" option along with other options

don't do anything billing related yet, but start the development for the family (multitenancy-like) plans: user should be able to invite their other profile (e.g. spouse, child, parent etc) to access and use the app, and the usecases of this are pretty complex, e.g. both parents having access to their child and their own health data, and both being able to edit everything etc - think of the most consistent way to do that, aka upgrading the profile to the multitenant legit account

make sure that users can create only one "self" profile

user creates their "self" profile, so the user avatar should be synced/reused/duplicated with the profile avatar

let's get rid of /app/account and /app/settings/personal and keep it all tied to the profiles instead

I neead a % completeness for every profile, to keep the users engaged. It can be a empty/filled circle around the avatar with a small current % badge in the corner (but they should be able to disable this somewhere in preferences). To do that it'd be good to get the user through an onboarding flow first:
1. Name, DoB and Sex, avatar etc
2. Optionally let them select another type of profile than self at this point - they might want to use it only for their child for example; so we need the "default" profile flag I think
2. Chronic Conditions
3. Health Events
4. Import Results
They can skip each step, the purpose of this is to half get their info and half inform them of the platform's capabilities.

cleanup "Your email address cannot be changed." from settings - it actually can be 



Update staff panel pages and sidenav:
- Health Events: grouping these one level below
  - Surgeries
  - Injuries
  - Sicknesses
  - Vaccines
  - Other
- Suggestions: all the user suggestions to be reviewed in one place, with a type column and the "Pending" filter on by default - so it is easy to glance and know what needs to be done

I want to transfer vaccines under the health events, and then make the health events even more sophisticated:
- predefined additional fields per event type: lot number and other for vaccines, expected and actual recovery times for surgery etc - please make a thorough list of these and update the forms accordingly - but keep in mind to make these extra values optional, so it is easy to add minimum amount of data and still get value from the app
- a functionality to add generic "reminders" to the event types - so for example due date for vaccines; it should be "smart", aka the system should now what's recommended per various types, so we can slowly build a database of these intuitive and user-friendly reminder suggestions
- a dedicated functionality to upload images (we can already upload generic files), so there's the event's gallery, e.g. for monitoring swelling etc

----

there needs to be a toast when navigating from confirming new and old email links, and info that the email was confirmed

update phone number form to have a separate select for the country code, searchable and fully functional, very sophisticated, with flags and codes


update the auth form layouts: sign in, sign up, reset password etc to be displayed side by side on desktop, using the second template (block?) from this website: https://ui.shadcn.com/blocks/login

update phone number form to have a separate select for the country code, searchable and fully functional, very sophisticated, with flags and codes

update email address change to send emails in development that are caught via letter opener so developer can actually test the whole flow

transactional emails are going to be sent using Brevo in production. Update the code, env vars and the docs accordingly

transactional SMS are going to be sent using Brevo in production, but also make it possible to enable via env var in development to test it out. update the code, env vars and the docs accordingly

exports shouldn't be available when there are no records

add custom date range to the Recent Results, and add identical dates filter to checkups

export.* translations are missing

Add 2FA support. I know nothing about how it is usually implemented, so I trust your best judgment to make it sound and secure via careful planning using your ROADMAP.md.

Thoroughly plan (write the roadmap) and then execute Notifications model:
- settings/preferences: both in bulk and per notification
- channels: in-app (this will also support push for phone apps later), email, phone (phone disabled by default)
- "mark as read" and "act on" when CTA exists and is clicked in the notification
- in-app notifications panel, with an ability to mark all as read
- controls to disable the whole channel
- predefined set of notification types, all with templates for in-app, email, phone: simple text that will later support handlebars
- move all the existing communication there, so the exact wording is controller via the staff panel
- needs to also match the user's i18n that they chose - so saving the message might need an AI-step to tranlsate into supported languages
- two types: instant and repetitive ("drip" functionality that's frequency etc is controlled via staff panel)
- then gather all types of events that it makes sense to notify the users of, and create a dedicated seed for all of them
- then update the relevant flows with dedicated interactors step that issues the notification
- then create background cron process to trigger subsequent drip notifications based on the preferences etc the events based on their frequency

Let's work on very sophisticated and informative PDF generation for the user's results full history. They should be able to select all the test results types (rows) that they want to include in the report, then optionally a date range for the report. Then there should be a background job to build and print a beautiful, multi-page PDF: with a chart of every selected lab result, well labeled etc. The purpose of it is so the user can share it with their doctors - right now only by downloading the PDF file to their system. List all of these in the new Reports page, with a status column and an ability to downlaod etc.


all rescue ActiveRecord::* exceptions need to be translated when passed to context.fail - don't pass plain english errors

the integration tests spec/requests are currently pretty vague - they only test for http 200, and it can be false positive - doesn't account for vite errors. I need the proper e2e tests, they need to do more, to interact with each rendered page in a way that it is supposed to work. propose a solution for this, e.g. using playwright/selenium/cypress, and prepare a comprehensive e2e tests suite that you can later run headless in CI or in browser locally. I need the tests to also check the contents of browser developers console on each page and make sure there are no errors and issues. this needs to be all thoroughlt documented in both readme and docs/testing, and to become a part of the ai agents development process to keepit up to date

I want all badges that are displayed within table cells to not wrap their text, and for the cell widths to expand freely to the biggest badge width


staff's All Imports table needs more data: date started and an action to download an actual file for every import, and a rspec test to try and go through the flow of any import, recording vcr communication with openai for multiple trial-errors

Add showing/hiding table columns functionality, then update all the app tables with it - so the user can adjust the view to their liking. Every custom attribute should be available as a column, with all un-checked by default - but they can add them as they please.  Also add "Export CSV" to the tables with their relevant data: health events, vaccines, test results, checkups, chronic conditions. 

Add new Settings/Contact section that will allow users to add more data: phone, email. They should be only able to reset their email after it is confirmed via both new and old email. Also add a way to verify the phone number. 


"Source" column values in Lab Tests table are missing translations

Every seed should be indempotent on the record level (upsert), so it is safe to run the seeds scripts again and again.

The normalized tests records need to be displayed in the Staff panel with all their related CRUD operations.


Refactor ranges.yml and test_categories/categories.yml into db/data/test_results/categories.yml, db/data/test_results/tests.yml and db/data/test_results/ranges.yml. Then:
1. Make sure that category has many tests
1. Make sure that test has many ranges - from least to most specific, based on profile, health events, chronic conditions
1. Make sure that the 3 of those are editable via staff panel - all CRUD actions in place
1. Scrape the internet and gather as many data of these as possible, take your time with it - we want to have it really complete and thourough.


Create db/data/test_results.yml for the app's  internal normalized database, and try sourcing the data from the internet, focusing on the most common tests.

Create a yml file in:
- db/data/providers/test_results/{provider}.yml
- db/data/providers/test_categories/{provider}.yml
for every provider from db/data/providers.yml, then for all providers available in Poland fill the data in sourcing the internet.


ActionController::ParameterMissing (param is missing or the value is empty or invalid: health_event):
app/controllers/app/health_events_controller.rb:109:in `health_event_params'
app/controllers/app/health_events_controller.rb:60:in `create'

move the manual entry button to be at the same height as the import heading, not both heading and paragraph

fix the issue on this page: http://localhost:3000/staff/vaccine_types
browser is open here, debug it yourself

users should be required to verify their email addresses


update the 50 files limit to 500 files, and max size to 500 MB 


avatar doesnt save on profile create


update the "Welcome back, display name" message to something more like "youre browsing in the context of your current selected profile display name", adjust the wording




it is easy to get mixed up with the files that you import, especially if there are many of them at the initial import. I want you to make the system as forgiving as possible while making sure the same file doesn't get processed over and over again. I think the best approach is to store file checksums somewhere - so we can have a guard before communicating with AI about a file that was already parsed. figure out the data model for this, as well as informing users via UI that there was a duplicate and it was previously processed

  
1. Create new profile
2. Refresh it's page
ActionView::Template::Error (Vite Ruby can't find entrypoints/application.css in the manifests.
Possible causes:
  - The last build failed. Try running `bin/vite build --clear --mode=development` manually and check for errors.
Errors:
  ✗ Build failed in 194ms
  error during build:
  [vite:json] [plugin vite:json] app/frontend/locales/pl/common.json: Failed to parse JSON file.
  file: /Users/me/ws/tzif.io/health/app/frontend/locales/pl/common.json
      at getRollupError (/Users/me/ws/tzif.io/health/node_modules/rollup/dist/es/shared/parseAst.js:402:45)
      at error (/Users/me/ws/tzif.io/health/node_modules/rollup/dist/es/shared/parseAst.js:398:42)
      at handler (/Users/me/ws/tzif.io/health/node_modules/vite/dist/node/chunks/dep-D4NMHUTW.js:12175:16)
      at <anonymous> (/Users/me/ws/tzif.io/health/node_modules/rollup/dist/es/shared/node-entry.js:22571:40)
      at processTicksAndRejections (native:7:39)
Visit the Troubleshooting guide for more information:
  https://vite-ruby.netlify.app/guide/troubleshooting.html#troubleshooting
)
Caused by: ViteRuby::MissingEntrypointError (Vite Ruby can't find entrypoints/application.css in the manifests.
Possible causes:
  - The last build failed. Try running `bin/vite build --clear --mode=development` manually and check for errors.
Errors:
  ✗ Build failed in 194ms
  error during build:
  [vite:json] [plugin vite:json] app/frontend/locales/pl/common.json: Failed to parse JSON file.
  file: /Users/me/ws/tzif.io/health/app/frontend/locales/pl/common.json
      at getRollupError (/Users/me/ws/tzif.io/health/node_modules/rollup/dist/es/shared/parseAst.js:402:45)
      at error (/Users/me/ws/tzif.io/health/node_modules/rollup/dist/es/shared/parseAst.js:398:42)
      at handler (/Users/me/ws/tzif.io/health/node_modules/vite/dist/node/chunks/dep-D4NMHUTW.js:12175:16)
      at <anonymous> (/Users/me/ws/tzif.io/health/node_modules/rollup/dist/es/shared/node-entry.js:22571:40)
      at processTicksAndRejections (native:7:39)
Visit the Troubleshooting guide for more information:
  https://vite-ruby.netlify.app/guide/troubleshooting.html#troubleshooting

)
Information for: ActionView::Template::Error (Vite Ruby can't find entrypoints/application.css in the manifests.
Possible causes:
  - The last build failed. Try running `bin/vite build --clear --mode=development` manually and check for errors.
Errors:
  ✗ Build failed in 194ms
  error during build:
  [vite:json] [plugin vite:json] app/frontend/locales/pl/common.json: Failed to parse JSON file.
  file: /Users/me/ws/tzif.io/health/app/frontend/locales/pl/common.json
      at getRollupError (/Users/me/ws/tzif.io/health/node_modules/rollup/dist/es/shared/parseAst.js:402:45)
      at error (/Users/me/ws/tzif.io/health/node_modules/rollup/dist/es/shared/parseAst.js:398:42)
      at handler (/Users/me/ws/tzif.io/health/node_modules/vite/dist/node/chunks/dep-D4NMHUTW.js:12175:16)
      at <anonymous> (/Users/me/ws/tzif.io/health/node_modules/rollup/dist/es/shared/node-entry.js:22571:40)
      at processTicksAndRejections (native:7:39)
Visit the Troubleshooting guide for more information:
  https://vite-ruby.netlify.app/guide/troubleshooting.html#troubleshooting

):
    17: 
    18:     <%= vite_client_tag %>
    19:     <%= vite_stylesheet_tag "entrypoints/application.css" %>
    20:     <%= vite_react_refresh_tag %>
    21: 
    22:     <script>
    23:       // Frontend configuration (from Config.frontend)
app/views/layouts/application.html.erb:20
app/controllers/app/profiles_controller.rb:14:in `show'
Information for cause: ViteRuby::MissingEntrypointError (Vite Ruby can't find entrypoints/application.css in the manifests.
Possible causes:
  - The last build failed. Try running `bin/vite build --clear --mode=development` manually and check for errors.
Errors:
  ✗ Build failed in 194ms
  error during build:
  [vite:json] [plugin vite:json] app/frontend/locales/pl/common.json: Failed to parse JSON file.
  file: /Users/me/ws/tzif.io/health/app/frontend/locales/pl/common.json
      at getRollupError (/Users/me/ws/tzif.io/health/node_modules/rollup/dist/es/shared/parseAst.js:402:45)
      at error (/Users/me/ws/tzif.io/health/node_modules/rollup/dist/es/shared/parseAst.js:398:42)
      at handler (/Users/me/ws/tzif.io/health/node_modules/vite/dist/node/chunks/dep-D4NMHUTW.js:12175:16)
      at <anonymous> (/Users/me/ws/tzif.io/health/node_modules/rollup/dist/es/shared/node-entry.js:22571:40)
      at processTicksAndRejections (native:7:39)
Visit the Troubleshooting guide for more information:
  https://vite-ruby.netlify.app/guide/troubleshooting.html#troubleshooting
):
app/views/layouts/application.html.erb:20
app/controllers/app/profiles_controller.rb:14:in `show'





Page layout may be unexpected due to Quirks Mode
One or more documents in this page is in Quirks Mode, which will render the affected document(s) with quirks incompatible with the current HTML and CSS specifications.
Quirks Mode exists mostly due to historical reasons. If this is not intentional, you can add or modify the DOCTYPE to be `<!DOCTYPE html>` to render the page in No Quirks Mode.
1 element
Document in the DOM tree	Mode	URL
document	Quirks Mode	http://localhost:3000/staff/medical_providers?page=9&sort=name&sort_direction=asc
Learn more: Document compatibility mode



A <label> isn't associated with a form field.
To fix this issue, nest the <input> in the <label> or provide a for attribute on the <label> that matches a form field id.
6 occurrences


A form field has an id or name attribute that the browser's autofill recognizes. However, it doesn't have an autocomplete attribute assigned. This might prevent the browser from correctly autofilling the form.
To fix this issue, provide an autocomplete attribute.
2 occurrences


A form field element has neither an id nor a name attribute. This might prevent the browser from correctly autofilling the form.
To fix this issue, add a unique id or name attribute to a form field. This is not strictly needed, but still recommended even if you have an autocomplete attribute on the same element.
53 occurrences



The label's for attribute doesn't match any element id. This might prevent the browser from correctly autofilling the form and accessibility tools from working correctly.
To fix this issue, make sure the label's for attribute references the correct id of a form field. 
There are 19 occurrences of this.




add search and date-ranges filtering to recent results table - make sure it follows the existing table controls conventions



display reference range description(s) in plain text on the single test result page, so user can learn what's what

checkups table need filters by provider and location: they need to be built based on only what user has actually added, don't display all options available in the system

make sure that sickness, injury, surgery use their unique informative icons everywhere they're displayed


vaccines table need manufacturer, provider and location filters: they need to be built based on only what user has actually added, don't display all options available in the system


the "Affect results" filter on the table is confusing, it says all/yes/no but doesnt explain to what it applies

figure out informativve unique icons for chronic conditions types


user: me
GET /staff/imports
AVOID eager loading detected
  Import => [:import_files]
  Remove from your query: .includes([:import_files])
Call stack
  /Users/me/ws/tzif.io/health/app/controllers/staff/imports_controller.rb:18:in `map'
  /Users/me/ws/tzif.io/health/app/controllers/staff/imports_controller.rb:18:in `index'



  
ActiveRecord::StatementInvalid (PG::UndefinedColumn: ERROR:  column "checkups_count" does not exist
LINE 1: ..."."id" GROUP BY "medical_providers"."id" ORDER BY checkups_c...
                                                             ^
)
Caused by: PG::UndefinedColumn (ERROR:  column "checkups_count" does not exist
LINE 1: ..."."id" GROUP BY "medical_providers"."id" ORDER BY checkups_c...
                                                             ^
)
Information for: ActiveRecord::StatementInvalid (PG::UndefinedColumn: ERROR:  column "checkups_count" does not exist
LINE 1: ..."."id" GROUP BY "medical_providers"."id" ORDER BY checkups_c...
                                                             ^
):
Information for cause: PG::UndefinedColumn (ERROR:  column "checkups_count" does not exist
LINE 1: ..."."id" GROUP BY "medical_providers"."id" ORDER BY checkups_c...
                                                             ^
):
app/controllers/concerns/indexable.rb:63:in `apply_index_params'
app/controllers/staff/medical_providers_controller.rb:14:in `index'


country filter for medical providers table in staff panel must be searchable - preferably reuse the component that is already used in the settings


there needs to be i18n switch in sidenav next to the theme switch, right now with polish and english only



every vaccine type that is displayed in the Due tab needs to have their educational page that explains:
- what is it for
- which countries it is distributed at
- what's the recommended frequency to get it done
any other info that you think is relevant. all this needs to be linked from the due table



update all "missing x? suggest it" to:
- have an optional URL field
- display info that they can still add it while we are reviewing this
- actually make it available to still add it while we are reviewing the suggestion



add a safety check to import processing to expect a big amount of known test results - this way a developer won't hit AI requests before seeding the database in the dev environment, and won't result in multiple unmatched results


table controls that are at the same line as the search bar need to be always kept in a single line, no matter if the control label is long etc. I think that the best / most common solution to this is to move filters and sorting under a single button that triggers a modal/popup/sth similar on small screens, and to keep the section mutliline (but responsive nicely, with a well though of layout) on desktop

all tables need background colors, ideally a little transparent and blurred

when sidenav opens theres error:
`DialogContent` requires a `DialogTitle` for the component to be accessible for screen reader users.
If you want to hide the `DialogTitle`, you can wrap it with our VisuallyHidden component.
For more information, see https://radix-ui.com/primitives/docs/components/dialog
also:
inertia-BcAFeceN.js:508 Warning: Missing `Description` or `aria-describedby={undefined}` for {DialogContent}.


improve profiles view cards styles, the padding is uneven and they are weirdly spaced



make the buttons on mobile a little smaller



move the "Manual Entry" to the top-right of the section instead of below the dropdown



go one by one through every staff page linked in staff sidenav - they all throw something went wrong exception
i want full e2e coverage of this pages and all actions performed there



custom attributes are not displayed during edit - not sure if they even save on create

custom attributes i18n are missing


  
ActiveRecord::InvalidForeignKey (PG::ForeignKeyViolation: ERROR:  update or delete on table "checkups" violates foreign key constraint "fk_rails_7de31c215c" on table "import_files"
DETAIL:  Key (id)=(17) is still referenced from table "import_files".
)
Caused by: PG::ForeignKeyViolation (ERROR:  update or delete on table "checkups" violates foreign key constraint "fk_rails_7de31c215c" on table "import_files"
DETAIL:  Key (id)=(17) is still referenced from table "import_files".
)
Information for: ActiveRecord::InvalidForeignKey (PG::ForeignKeyViolation: ERROR:  update or delete on table "checkups" violates foreign key constraint "fk_rails_7de31c215c" on table "import_files"
DETAIL:  Key (id)=(17) is still referenced from table "import_files".
):
Information for cause: PG::ForeignKeyViolation (ERROR:  update or delete on table "checkups" violates foreign key constraint "fk_rails_7de31c215c" on table "import_files"
DETAIL:  Key (id)=(17) is still referenced from table "import_files".
):
app/interactors/checkups/delete.rb:8:in `call'
app/controllers/app/checkups_controller.rb:101:in `destroy'







update the system prompt to instruct the specific behavior for all unmatched tests. when the test is unmatched, it needs to be saved as-is with a "pending review" flag, all these need to be displayed for staff users to research and verify (e.g. we can actually have a match, so they can merge it with existing test, or if we don't they can create a new on). the user needs to see these separately on the checkup in the idle/pending state, and they need to be informed that human work is in progress on this part of their result

the main goal here is to not spoil/denormalize existing data: that's why we need to keep them separate







we keep the normalized tests results, but the AI needs to also extract and sync how the providers do this, so we can slowly built a database of various providers and see if there are any discrepancies between them. i'd propose the following return format:
```json
{
"normalized_results": [{"test_name": "", "value": "" }] // the rest comes from our normalization database
"provider_interpretations: [{
  "normalized_test_name": "", // for matching with our normalized data
  "provider_test_name": "",
  "provider_unit": "",
  "provider_ref_min": "",
  "provider_ref_max": "",
  "provider_flag": "",
  "provider_data": {}, // to gather key-value of all other information stored by providers that is related to this test
  }]
  "unmatched_results": [{
  "provider_test_name": "",
  "provider_unit": "",
  "provider_value": "",
  "provider_ref_min": "",
  "provider_ref_max": "",
  "provider_flag": "",
  "provider_data": {}, // to gather key-value of all other information stored by providers that is related to this test
  }] 
}
```

I think it covers this usecase, but fill free to expand. Once it is in place, work on roadmap items for the staff users to browse the unmatched tests, so they can match manually or create new records in our normalized database.
