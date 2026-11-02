# atm-iris-ios

iPad companion of **Iris Desktop** (`../atm-iris-desktop`): a remote control the person leading the service holds
(next/previous slide, clear screen, timer, Bible). The computer keeps projecting; the iPad only sends commands and
shows state over the church Wi-Fi.

**Status: mockup.** All earlier functionality (account, API sync, projection, playback) was removed on purpose; only
the design system remains (`iris/DesignSystem`: tokens and components). The screens in `iris/Mockup` use sample data
from `MockData.swift` and talk to nothing. Code in English, user-facing text in Spanish.

`IRIS_SPEC.md` is the design reference (tokens §3–4, components §5). Its screens, login, modules and API sections
describe the old product and no longer apply.
