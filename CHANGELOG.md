# Changelog

## [2.4.0](https://github.com/gerfru/homelab-gateway/compare/v2.3.0...v2.4.0) (2026-06-16)


### Features

* add Gitea Actions runner (act_runner) ([#79](https://github.com/gerfru/homelab-gateway/issues/79)) ([66e1d52](https://github.com/gerfru/homelab-gateway/commit/66e1d5239eb1eecc12ed8225d4944fe1fed8b5c5))
* add Gitea, PostgreSQL, Renovate, and GitHub mirror ([#65](https://github.com/gerfru/homelab-gateway/issues/65)) ([b3b125d](https://github.com/gerfru/homelab-gateway/commit/b3b125d71163b84d2052c7cbfec6705a4c76060e))
* add github-to-gitea-sync script ([#78](https://github.com/gerfru/homelab-gateway/issues/78)) ([5e9815a](https://github.com/gerfru/homelab-gateway/commit/5e9815a004381bf85e252424c1e8dd1131853742))
* add macOS support for CoreDNS and CI pipeline ([02de45f](https://github.com/gerfru/homelab-gateway/commit/02de45f79d91091598724adf23e81ca3eef61134))
* add macOS support for CoreDNS and CI pipeline ([cb0341e](https://github.com/gerfru/homelab-gateway/commit/cb0341ea24f96cfb7ac5552aafbe5b58f01792b6))
* add observability alerting, scrape coverage, and PII redaction ([#32](https://github.com/gerfru/homelab-gateway/issues/32)) ([c3615ee](https://github.com/gerfru/homelab-gateway/commit/c3615ee42ec1816d5ff04cf40c64526e024c6746))
* add Prometheus and Node Exporter for system monitoring, update Grafana dashboards ([54096b6](https://github.com/gerfru/homelab-gateway/commit/54096b65c5390f60cfbc5f32f14f5613963fd0ce))
* add repo security gates ([#25](https://github.com/gerfru/homelab-gateway/issues/25)) ([6292d79](https://github.com/gerfru/homelab-gateway/commit/6292d796275694692121574ca46ff062c480c9b9))
* add smart-sync modes to github-to-gitea-sync ([05226a1](https://github.com/gerfru/homelab-gateway/commit/05226a108617d624d1519f7a3b6f78cb8d809a8b))
* add testing foundation with golden-file, DNS, and smoke tests (#W7) ([#40](https://github.com/gerfru/homelab-gateway/issues/40)) ([4ae3986](https://github.com/gerfru/homelab-gateway/commit/4ae3986fa562ba3128668d3665ea00d56d92c8f6))
* add tracing, auto-updates, and monitoring auth (#W8) ([#42](https://github.com/gerfru/homelab-gateway/issues/42)) ([dbe67af](https://github.com/gerfru/homelab-gateway/commit/dbe67af962093d7064a1f8c82d7c48ff1197fc1e))
* add update-ip script and IP rotation runbook ([#76](https://github.com/gerfru/homelab-gateway/issues/76)) ([def6bfd](https://github.com/gerfru/homelab-gateway/commit/def6bfdfd6267b76245bc858c8f10dca7f61e597))
* add Uptime Kuma monitor provisioning script ([#34](https://github.com/gerfru/homelab-gateway/issues/34)) ([c688dc1](https://github.com/gerfru/homelab-gateway/commit/c688dc17ea1b0b57c65a68de4e3f44577ca70514))
* enhance configuration and security settings across multiple files ([dd6befe](https://github.com/gerfru/homelab-gateway/commit/dd6befe7b0f83a5370c09b78eb6bedf3482dcedf))
* expose Prometheus UI and Caddy metrics via subdomains ([#33](https://github.com/gerfru/homelab-gateway/issues/33)) ([87b6fe2](https://github.com/gerfru/homelab-gateway/commit/87b6fe2b26a1095018f0b1f03f629d778ffb7573))
* extend CI with Trivy, Semgrep, Checkov, and SBOM ([#29](https://github.com/gerfru/homelab-gateway/issues/29)) ([eb1eee4](https://github.com/gerfru/homelab-gateway/commit/eb1eee471f4180bf733bc160cf3c920dc10f0a74))
* Gitea monitoring, stack fixes, docs update ([#71](https://github.com/gerfru/homelab-gateway/issues/71)) ([3e4e9db](https://github.com/gerfru/homelab-gateway/commit/3e4e9db4603a77b5e1fb93b5e5ecfd8e4c770512))
* harden containers and add Docker socket proxy ([#27](https://github.com/gerfru/homelab-gateway/issues/27)) ([671cd70](https://github.com/gerfru/homelab-gateway/commit/671cd70714616482f6d5c18a10dea827d2db6d22))
* implement Wave 1 + Wave 2 (CI security gates, secrets, onboarding) ([#51](https://github.com/gerfru/homelab-gateway/issues/51)) ([d229492](https://github.com/gerfru/homelab-gateway/commit/d22949247c575e4c2f203272033c7a142e389a74))
* implement Wave 3 (alerting & observability) ([#53](https://github.com/gerfru/homelab-gateway/issues/53)) ([ec46692](https://github.com/gerfru/homelab-gateway/commit/ec46692025b54f3b0ece953cd48dbcc8d6aaa14d))
* implement Wave 4 (security hardening) ([#54](https://github.com/gerfru/homelab-gateway/issues/54)) ([fa7ae9b](https://github.com/gerfru/homelab-gateway/commit/fa7ae9b51df2c3c58f43a031fc52563b925f4f88))
* implement Wave 5 (tests & CI coverage) ([#55](https://github.com/gerfru/homelab-gateway/issues/55)) ([e671809](https://github.com/gerfru/homelab-gateway/commit/e671809e53a1d31a6321c9e7fd809257689c8d94))
* implement Wave 6 (documentation & operator polish) ([#57](https://github.com/gerfru/homelab-gateway/issues/57)) ([901b9dd](https://github.com/gerfru/homelab-gateway/commit/901b9dd9f8fa6584ccab4b033a5f346c64e8f175))
* implement Wave 7 (infrastructure polish, configurability, evaluations) ([#59](https://github.com/gerfru/homelab-gateway/issues/59)) ([8196066](https://github.com/gerfru/homelab-gateway/commit/8196066b12c5e0cf72456a7ea92fcdf49f0dc0f7))
* initial homelab-gateway with CoreDNS + Caddy ([cf86483](https://github.com/gerfru/homelab-gateway/commit/cf8648372ea8a654e35f92d8bbc04c531e8dcfa2))
* **monitoring:** integrate Niles into observability stack ([#97](https://github.com/gerfru/homelab-gateway/issues/97)) ([c69b81c](https://github.com/gerfru/homelab-gateway/commit/c69b81c6d67ffcdf4c6016f0d7c427e8bc9a59a4))
* restructure home lab setup with monitoring and logging services ([e2824da](https://github.com/gerfru/homelab-gateway/commit/e2824da82784a259cd2cef9238bb894bff41b05a))
* templatize Caddyfile and improve config hygiene ([#28](https://github.com/gerfru/homelab-gateway/issues/28)) ([7ca20b7](https://github.com/gerfru/homelab-gateway/commit/7ca20b7aabcb1e9d9b0fdc5ab4596b0a8c349a65))


### Bug Fixes

* break long line in claude.yml to pass yamllint ([66d3ce6](https://github.com/gerfru/homelab-gateway/commit/66d3ce6030775d11ec4ce7783f68d3dee3ab798f))
* correct yamllint action SHA and add Dependabot for GitHub Actions ([56dc85e](https://github.com/gerfru/homelab-gateway/commit/56dc85e8ec675ca5befb86021943ae16797d0a65))
* exclude macOS Docker Desktop filesystems from node-exporter ([#36](https://github.com/gerfru/homelab-gateway/issues/36)) ([edc0a41](https://github.com/gerfru/homelab-gateway/commit/edc0a4110209cf958a21a290c3379babf10dd239))
* harden Makefile env handling, default credentials, and shell quality (#W6) ([#38](https://github.com/gerfru/homelab-gateway/issues/38)) ([a08efa9](https://github.com/gerfru/homelab-gateway/commit/a08efa97b16ed444971876d080ddad258958f251))
* increase Tempo start_period to 40s, add stack-ready wait in smoke test ([#72](https://github.com/gerfru/homelab-gateway/issues/72)) ([eff401c](https://github.com/gerfru/homelab-gateway/commit/eff401cccc5b9ad21a587f66ce1bd9696d7a6f2f))
* public-repo readiness + feat: arbscanner integration ([#84](https://github.com/gerfru/homelab-gateway/issues/84)) ([817e1e7](https://github.com/gerfru/homelab-gateway/commit/817e1e791a4d084288a63e04909586b0c1f41b3f))
* reduce arbscanner memory limit to 768m ([#89](https://github.com/gerfru/homelab-gateway/issues/89)) ([5f435ed](https://github.com/gerfru/homelab-gateway/commit/5f435ed056f32c541a27676f2387c5557d50faa9))
* remove personal paths and generalize platform-specific config ([5448936](https://github.com/gerfru/homelab-gateway/commit/54489366e6759df548980d538aace9f09cb8d9c6))
* remove unsupported yamllint option forbid-duplicated-merge-keys ([fcd6736](https://github.com/gerfru/homelab-gateway/commit/fcd6736379c3256eead8a1cb3e1bbd59c940ba75))
* replace internal hostname in CLAUDE.md ([9f42721](https://github.com/gerfru/homelab-gateway/commit/9f4272177a48f930df3113a97fb8db9ad0e1dd5d))
* smoke test queries Prometheus via container exec ([#50](https://github.com/gerfru/homelab-gateway/issues/50)) ([221166e](https://github.com/gerfru/homelab-gateway/commit/221166e14578a55c6dd4ab65fc58ade892024e4c))
* stop arbscanner in make down and add optional smoke test ([#86](https://github.com/gerfru/homelab-gateway/issues/86)) ([ca0a0e4](https://github.com/gerfru/homelab-gateway/commit/ca0a0e460cac183cc81f963cb03acf45b25473e4))

## [2.3.0](https://github.com/gerfru/homelab-gateway/compare/v2.2.2...v2.3.0) (2026-06-15)


### Features

* add Gitea Actions runner (act_runner) ([#79](https://github.com/gerfru/homelab-gateway/issues/79)) ([66e1d52](https://github.com/gerfru/homelab-gateway/commit/66e1d5239eb1eecc12ed8225d4944fe1fed8b5c5))
* add Gitea, PostgreSQL, Renovate, and GitHub mirror ([#65](https://github.com/gerfru/homelab-gateway/issues/65)) ([b3b125d](https://github.com/gerfru/homelab-gateway/commit/b3b125d71163b84d2052c7cbfec6705a4c76060e))
* add github-to-gitea-sync script ([#78](https://github.com/gerfru/homelab-gateway/issues/78)) ([5e9815a](https://github.com/gerfru/homelab-gateway/commit/5e9815a004381bf85e252424c1e8dd1131853742))
* add macOS support for CoreDNS and CI pipeline ([02de45f](https://github.com/gerfru/homelab-gateway/commit/02de45f79d91091598724adf23e81ca3eef61134))
* add macOS support for CoreDNS and CI pipeline ([cb0341e](https://github.com/gerfru/homelab-gateway/commit/cb0341ea24f96cfb7ac5552aafbe5b58f01792b6))
* add observability alerting, scrape coverage, and PII redaction ([#32](https://github.com/gerfru/homelab-gateway/issues/32)) ([c3615ee](https://github.com/gerfru/homelab-gateway/commit/c3615ee42ec1816d5ff04cf40c64526e024c6746))
* add Prometheus and Node Exporter for system monitoring, update Grafana dashboards ([54096b6](https://github.com/gerfru/homelab-gateway/commit/54096b65c5390f60cfbc5f32f14f5613963fd0ce))
* add repo security gates ([#25](https://github.com/gerfru/homelab-gateway/issues/25)) ([6292d79](https://github.com/gerfru/homelab-gateway/commit/6292d796275694692121574ca46ff062c480c9b9))
* add smart-sync modes to github-to-gitea-sync ([05226a1](https://github.com/gerfru/homelab-gateway/commit/05226a108617d624d1519f7a3b6f78cb8d809a8b))
* add testing foundation with golden-file, DNS, and smoke tests (#W7) ([#40](https://github.com/gerfru/homelab-gateway/issues/40)) ([4ae3986](https://github.com/gerfru/homelab-gateway/commit/4ae3986fa562ba3128668d3665ea00d56d92c8f6))
* add tracing, auto-updates, and monitoring auth (#W8) ([#42](https://github.com/gerfru/homelab-gateway/issues/42)) ([dbe67af](https://github.com/gerfru/homelab-gateway/commit/dbe67af962093d7064a1f8c82d7c48ff1197fc1e))
* add update-ip script and IP rotation runbook ([#76](https://github.com/gerfru/homelab-gateway/issues/76)) ([def6bfd](https://github.com/gerfru/homelab-gateway/commit/def6bfdfd6267b76245bc858c8f10dca7f61e597))
* add Uptime Kuma monitor provisioning script ([#34](https://github.com/gerfru/homelab-gateway/issues/34)) ([c688dc1](https://github.com/gerfru/homelab-gateway/commit/c688dc17ea1b0b57c65a68de4e3f44577ca70514))
* enhance configuration and security settings across multiple files ([dd6befe](https://github.com/gerfru/homelab-gateway/commit/dd6befe7b0f83a5370c09b78eb6bedf3482dcedf))
* expose Prometheus UI and Caddy metrics via subdomains ([#33](https://github.com/gerfru/homelab-gateway/issues/33)) ([87b6fe2](https://github.com/gerfru/homelab-gateway/commit/87b6fe2b26a1095018f0b1f03f629d778ffb7573))
* extend CI with Trivy, Semgrep, Checkov, and SBOM ([#29](https://github.com/gerfru/homelab-gateway/issues/29)) ([eb1eee4](https://github.com/gerfru/homelab-gateway/commit/eb1eee471f4180bf733bc160cf3c920dc10f0a74))
* Gitea monitoring, stack fixes, docs update ([#71](https://github.com/gerfru/homelab-gateway/issues/71)) ([3e4e9db](https://github.com/gerfru/homelab-gateway/commit/3e4e9db4603a77b5e1fb93b5e5ecfd8e4c770512))
* harden containers and add Docker socket proxy ([#27](https://github.com/gerfru/homelab-gateway/issues/27)) ([671cd70](https://github.com/gerfru/homelab-gateway/commit/671cd70714616482f6d5c18a10dea827d2db6d22))
* implement Wave 1 + Wave 2 (CI security gates, secrets, onboarding) ([#51](https://github.com/gerfru/homelab-gateway/issues/51)) ([d229492](https://github.com/gerfru/homelab-gateway/commit/d22949247c575e4c2f203272033c7a142e389a74))
* implement Wave 3 (alerting & observability) ([#53](https://github.com/gerfru/homelab-gateway/issues/53)) ([ec46692](https://github.com/gerfru/homelab-gateway/commit/ec46692025b54f3b0ece953cd48dbcc8d6aaa14d))
* implement Wave 4 (security hardening) ([#54](https://github.com/gerfru/homelab-gateway/issues/54)) ([fa7ae9b](https://github.com/gerfru/homelab-gateway/commit/fa7ae9b51df2c3c58f43a031fc52563b925f4f88))
* implement Wave 5 (tests & CI coverage) ([#55](https://github.com/gerfru/homelab-gateway/issues/55)) ([e671809](https://github.com/gerfru/homelab-gateway/commit/e671809e53a1d31a6321c9e7fd809257689c8d94))
* implement Wave 6 (documentation & operator polish) ([#57](https://github.com/gerfru/homelab-gateway/issues/57)) ([901b9dd](https://github.com/gerfru/homelab-gateway/commit/901b9dd9f8fa6584ccab4b033a5f346c64e8f175))
* implement Wave 7 (infrastructure polish, configurability, evaluations) ([#59](https://github.com/gerfru/homelab-gateway/issues/59)) ([8196066](https://github.com/gerfru/homelab-gateway/commit/8196066b12c5e0cf72456a7ea92fcdf49f0dc0f7))
* initial homelab-gateway with CoreDNS + Caddy ([cf86483](https://github.com/gerfru/homelab-gateway/commit/cf8648372ea8a654e35f92d8bbc04c531e8dcfa2))
* restructure home lab setup with monitoring and logging services ([e2824da](https://github.com/gerfru/homelab-gateway/commit/e2824da82784a259cd2cef9238bb894bff41b05a))
* templatize Caddyfile and improve config hygiene ([#28](https://github.com/gerfru/homelab-gateway/issues/28)) ([7ca20b7](https://github.com/gerfru/homelab-gateway/commit/7ca20b7aabcb1e9d9b0fdc5ab4596b0a8c349a65))


### Bug Fixes

* break long line in claude.yml to pass yamllint ([66d3ce6](https://github.com/gerfru/homelab-gateway/commit/66d3ce6030775d11ec4ce7783f68d3dee3ab798f))
* correct yamllint action SHA and add Dependabot for GitHub Actions ([56dc85e](https://github.com/gerfru/homelab-gateway/commit/56dc85e8ec675ca5befb86021943ae16797d0a65))
* exclude macOS Docker Desktop filesystems from node-exporter ([#36](https://github.com/gerfru/homelab-gateway/issues/36)) ([edc0a41](https://github.com/gerfru/homelab-gateway/commit/edc0a4110209cf958a21a290c3379babf10dd239))
* harden Makefile env handling, default credentials, and shell quality (#W6) ([#38](https://github.com/gerfru/homelab-gateway/issues/38)) ([a08efa9](https://github.com/gerfru/homelab-gateway/commit/a08efa97b16ed444971876d080ddad258958f251))
* increase Tempo start_period to 40s, add stack-ready wait in smoke test ([#72](https://github.com/gerfru/homelab-gateway/issues/72)) ([eff401c](https://github.com/gerfru/homelab-gateway/commit/eff401cccc5b9ad21a587f66ce1bd9696d7a6f2f))
* public-repo readiness + feat: arbscanner integration ([#84](https://github.com/gerfru/homelab-gateway/issues/84)) ([817e1e7](https://github.com/gerfru/homelab-gateway/commit/817e1e791a4d084288a63e04909586b0c1f41b3f))
* reduce arbscanner memory limit to 768m ([#89](https://github.com/gerfru/homelab-gateway/issues/89)) ([5f435ed](https://github.com/gerfru/homelab-gateway/commit/5f435ed056f32c541a27676f2387c5557d50faa9))
* remove personal paths and generalize platform-specific config ([5448936](https://github.com/gerfru/homelab-gateway/commit/54489366e6759df548980d538aace9f09cb8d9c6))
* remove unsupported yamllint option forbid-duplicated-merge-keys ([fcd6736](https://github.com/gerfru/homelab-gateway/commit/fcd6736379c3256eead8a1cb3e1bbd59c940ba75))
* replace internal hostname in CLAUDE.md ([9f42721](https://github.com/gerfru/homelab-gateway/commit/9f4272177a48f930df3113a97fb8db9ad0e1dd5d))
* smoke test queries Prometheus via container exec ([#50](https://github.com/gerfru/homelab-gateway/issues/50)) ([221166e](https://github.com/gerfru/homelab-gateway/commit/221166e14578a55c6dd4ab65fc58ade892024e4c))
* stop arbscanner in make down and add optional smoke test ([#86](https://github.com/gerfru/homelab-gateway/issues/86)) ([ca0a0e4](https://github.com/gerfru/homelab-gateway/commit/ca0a0e460cac183cc81f963cb03acf45b25473e4))

## [2.2.2](https://github.com/gerfru/homelab-gateway/compare/v2.2.1...v2.2.2) (2026-06-14)


### Bug Fixes

* reduce arbscanner memory limit to 768m ([#89](https://github.com/gerfru/homelab-gateway/issues/89)) ([5f435ed](https://github.com/gerfru/homelab-gateway/commit/5f435ed056f32c541a27676f2387c5557d50faa9))

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
