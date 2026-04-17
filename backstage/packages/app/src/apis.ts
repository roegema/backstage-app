import {
  ScmAuth,
  ScmIntegrationsApi,
  scmIntegrationsApiRef,
} from '@backstage/integration-react';

import {
  AnyApiFactory,
  configApiRef,
  createApiFactory,
} from '@backstage/core-plugin-api';

export const apis: AnyApiFactory[] = [
  // SCM integrations (you already had this, it's correct)
  createApiFactory({
    api: scmIntegrationsApiRef,
    deps: { configApi: configApiRef },
    factory: ({ configApi }) =>
      ScmIntegrationsApi.fromConfig(configApi),
  }),

  // ✅ THIS is what supplies core.scmauth
  ScmAuth.createDefaultApiFactory(),
];
