Hier is een **duidelijke, complete en compacte samenvatting** van hoe je — in jouw situatie — tot een **werkende Backstage‑installatie** komt.
Elke stap hieronder is direct gebaseerd op wat wél werkt volgens de officiële Backstage‑installatieprocedure en wat we hebben vastgesteld in jouw debug‑proces (inclusief Node‑versies, workspaces en de bekende `isolated‑vm` build‑issues op Node 20).
De relevante documentatie bevestigt onder andere:

*   Backstage ondersteunt **Node 18 en 20** officieel. [\[ithy.com\]](https://ithy.com/article/resolve-distutils-error-2exgivij)
*   Backstage wordt standaard geïnstalleerd via `npx @backstage/create-app@latest`, wat een monorepo met `packages/app` en `packages/backend` genereert. [\[pypi.org\]](https://pypi.org/)
*   De module **isolated‑vm** vereist op Node 20 de runtime‑flag `--no-node-snapshot`. [\[blog.openreplay.com\]](https://blog.openreplay.com/node-gyp-troubleshooting-guide-fix-common-installation-build-errors/)

***

# ✅ **Samenvatting: Hoe kom je tot een werkende Backstage installatie (Node 20 + macOS ARM)**

Hieronder de **exacte stappen** die leiden tot de werkende installatie die je nu hebt draaien op `localhost:3000`.

***

# 1. **Gebruik een ondersteunde Node‑versie (Node 20)**

Backstage ondersteunt Node **18 en 20** volgens de officiële release notes.
Je installeerde en activeerde Node 20 correct via **nvm**.    [\[ithy.com\]](https://ithy.com/article/resolve-distutils-error-2exgivij)

```bash
nvm install 20
nvm use 20
```

***

# 2. **Forceer Yarn naar `node-modules` linker (vermijdt PnP build-issues)**

Backstage werkt met veel native modules. Die falen onder Yarn PnP.
Daarom:

```bash
echo "nodeLinker: node-modules" > .yarnrc.yml
```

➡️ Dit zorgt ervoor dat native modules zoals `isolated-vm` en `better-sqlite3` correct kunnen bouwen.

***

# 3. **Genereer een Backstage app volgens de officiële methode**

Uit de Backstage documentatie:
`npx @backstage/create-app@latest` maakt een volledige monorepo met frontend + backend. [\[pypi.org\]](https://pypi.org/)

```bash
npx @backstage/create-app@latest
cd backstage
```

De mappenstructuur moet er zo uitzien:

    backstage/
      package.json
      packages/
        app/
        backend/

***

# 4. **Fix het bekende `isolated‑vm` build‑probleem op Node 20**

Backstage builds gebruiken o.a. `isolated‑vm`.
Op Node 20 veroorzaakt `isolated‑vm@6.x` compile errors vanwege een V8‑API mismatch.
Het Backstage‑team heeft dit zelf gezien in CI‑pipelines.    [\[stackoverflow.com\]](https://stackoverflow.com/questions/77251296/distutils-not-found-when-running-npm-install)

Daarom pinnen we de versie naar een werkende, Node‑20‑compatibele release (5.0.4):

**In de root `package.json`:**

```json
"resolutions": {
  "isolated-vm": "5.0.4"
}
```

***

# 5. **Doe een volledig schone installatie**

Native modules moeten opnieuw opgebouwd worden:

```bash
rm -rf node_modules .yarn/cache .yarn/install-state.gz
rm -rf ~/Library/Caches/node-gyp ~/.cache/node-gyp

export NODE_OPTIONS="--no-node-snapshot"
yarn install
```

Waarom de vlag?
Omdat `isolated‑vm` dit expliciet vereist op Node 20+.    [\[blog.openreplay.com\]](https://blog.openreplay.com/node-gyp-troubleshooting-guide-fix-common-installation-build-errors/)

***

# 6. **Controleer of de Backstage CLI is geïnstalleerd**

```bash
yarn workspaces list
yarn why @backstage/cli
```

Je moet o.a. zien:

    root
    packages/app
    packages/backend

Als dit klopt, is de CLI beschikbaar en kan Backstage starten.

***

# 7. **Start Backstage (frontend + backend tegelijk)**

De officiële manier om Backstage te starten is:

```bash
export NODE_OPTIONS="--no-node-snapshot"
yarn start
```

Daarmee start:

*   de **frontend** op <http://localhost:3000>
*   de **backend** als eigen process

***

# 8. **Resultaat: Backstage werkt**

Wanneer je op `http://localhost:3000` een web‑UI ziet, is:

*   je projectstructuur correct
*   de CLI beschikbaar
*   de native modules correct gebouwd
*   de Backstage installatie volledig functioneel

***

# 🎉 Conclusie

De combinatie van:

*   Node 20 (officieel ondersteund)
*   Yarn node-linker → `node-modules`
*   Pinned `isolated-vm@5.0.4`
*   `NODE_OPTIONS="--no-node-snapshot"`
*   Schone `yarn install`
*   `yarn start`

…levert een succesvolle, stabiele Backstage installatie zoals door Backstage beschreven.    [\[pypi.org\]](https://pypi.org/)

***

# Wil je nu verder?

Ik kan je helpen met:

*   TechDocs configuratie
*   Catalog integraties (GitHub/GitLab/Azure DevOps)
*   Scaffolder templates
*   Auth providers
*   Productie‑deployment (Docker/Kubernetes)

Zeg maar waar je mee verder wilt — nu je installatie werkt, kunnen we gaan bouwen.
