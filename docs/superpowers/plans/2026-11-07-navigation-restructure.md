# Navigation restructure

Goal: stop the tab sidebar reaching the player, replace ad-hoc navigation with one model, and
rebuild the sidebar like the Apple TV app.

## Steps
1. Add `AppNavigator` (selected tab, one path per tab, player presentation) and `AppRoute`.
2. Present `PlayerView` and `ShortsPlayerView` from one `fullScreenCover` on the `TabView`.
   Remove per-view player destinations and `.toolbar(.hidden, for: .tabBar)`.
3. Replace `.openChannel` / `.navigateToSearch` and per-view `navigationDestination(item:)` with
   navigator calls. The player's channel action closes the player, then pushes the channel.
4. Sidebar: account header, Search, Home (was Recommended), Subscriptions, Library, Settings, then a
   Channels section sorted alphabetically (subscriptions plus local follows).
5. Fix the bugs from the audit: channel error alert, Library sign-in push, tab title localization.
6. Update `docs/architecture.md` and add an ADR. Compile throughout; unit tests at the end. Check
   sidebar focus in the simulator, because `TabSection` and the sidebar header have known tvOS risks.
