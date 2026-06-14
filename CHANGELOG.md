# Changelog

## [2.2.1](https://github.com/gerfru/homelab-gateway/compare/v2.2.0...v2.2.1) (2026-06-14)


### Bug Fixes

* stop arbscanner in make down and add optional smoke test ([#86](https://github.com/gerfru/homelab-gateway/issues/86)) ([ca0a0e4](https://github.com/gerfru/homelab-gateway/commit/ca0a0e460cac183cc81f963cb03acf45b25473e4))

## [2.2.0](https://github.com/gerfru/homelab-gateway/compare/v2.1.0...v2.2.0) (2026-06-14)


### Features

* add Gitea Actions runner (act_runner) ([#79](https://github.com/gerfru/homelab-gateway/issues/79)) ([66e1d52](https://github.com/gerfru/homelab-gateway/commit/66e1d5239eb1eecc12ed8225d4944fe1fed8b5c5))
* add github-to-gitea-sync script ([#78](https://github.com/gerfru/homelab-gateway/issues/78)) ([5e9815a](https://github.com/gerfru/homelab-gateway/commit/5e9815a004381bf85e252424c1e8dd1131853742))
* add smart-sync modes to github-to-gitea-sync ([05226a1](https://github.com/gerfru/homelab-gateway/commit/05226a108617d624d1519f7a3b6f78cb8d809a8b))
* add update-ip script and IP rotation runbook ([#76](https://github.com/gerfru/homelab-gateway/issues/76)) ([def6bfd](https://github.com/gerfru/homelab-gateway/commit/def6bfdfd6267b76245bc858c8f10dca7f61e597))


### Bug Fixes

* public-repo readiness + feat: arbscanner integration ([#84](https://github.com/gerfru/homelab-gateway/issues/84)) ([817e1e7](https://github.com/gerfru/homelab-gateway/commit/817e1e791a4d084288a63e04909586b0c1f41b3f))
* remove personal paths and generalize platform-specific config ([5448936](https://github.com/gerfru/homelab-gateway/commit/54489366e6759df548980d538aace9f09cb8d9c6))
* replace internal hostname in CLAUDE.md ([9f42721](https://github.com/gerfru/homelab-gateway/commit/9f4272177a48f930df3113a97fb8db9ad0e1dd5d))

## [2.1.0](https://github.com/gerfru/homelab-gateway/compare/v2.0.0...v2.1.0) (2026-06-12)


### Features

* Gitea monitoring, stack fixes, docs update ([#71](https://github.com/gerfru/homelab-gateway/issues/71)) ([2aebccc](https://github.com/gerfru/homelab-gateway/commit/2aebcccd27c0e322460aafa0989028b3825649e8))


### Bug Fixes

* increase Tempo start_period to 40s, add stack-ready wait in smoke test ([#72](https://github.com/gerfru/homelab-gateway/issues/72)) ([023f660](https://github.com/gerfru/homelab-gateway/commit/023f6608bffad4a4957db628730524e255906d32))
