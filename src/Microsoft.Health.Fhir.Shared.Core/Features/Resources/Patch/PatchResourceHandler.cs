﻿// -------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See LICENSE in the repo root for license information.
// -------------------------------------------------------------------------------------------------

using System;
using System.Threading;
using System.Threading.Tasks;
using EnsureThat;
using MediatR;
using Microsoft.Health.Core.Features.Security.Authorization;
using Microsoft.Health.Fhir.Core.Exceptions;
using Microsoft.Health.Fhir.Core.Features.Conformance;
using Microsoft.Health.Fhir.Core.Features.Persistence;
using Microsoft.Health.Fhir.Core.Features.Security;
using Microsoft.Health.Fhir.Core.Messages.Patch;
using Microsoft.Health.Fhir.Core.Messages.Upsert;
using Microsoft.Health.Fhir.Core.Models;

namespace Microsoft.Health.Fhir.Core.Features.Resources.Patch
{
    public class PatchResourceHandler : BaseResourceHandler, IRequestHandler<PatchResourceRequest, UpsertResourceResponse>
    {
        private readonly JsonPatchService _patchService;
        private readonly IMediator _mediator;

        public PatchResourceHandler(
            IMediator mediator,
            IFhirDataStore fhirDataStore,
            Lazy<IConformanceProvider> conformanceProvider,
            IResourceWrapperFactory resourceWrapperFactory,
            ResourceIdProvider resourceIdProvider,
            IAuthorizationService<DataActions> authorizationService,
            IModelInfoProvider modelInfoProvider)
            : base(fhirDataStore, conformanceProvider, resourceWrapperFactory, resourceIdProvider, authorizationService)
        {
            EnsureArg.IsNotNull(modelInfoProvider, nameof(modelInfoProvider));
            EnsureArg.IsNotNull(mediator, nameof(mediator));

            _patchService = new JsonPatchService(modelInfoProvider);
            _mediator = mediator;
        }

        public async Task<UpsertResourceResponse> Handle(PatchResourceRequest request, CancellationToken cancellationToken)
        {
            EnsureArg.IsNotNull(request, nameof(request));

            if (await AuthorizationService.CheckAccess(DataActions.Read | DataActions.Write, cancellationToken) != (DataActions.Read | DataActions.Write))
            {
                throw new UnauthorizedFhirActionException();
            }

            ResourceKey key = request.ResourceKey;

            if (!string.IsNullOrEmpty(key.VersionId))
            {
                throw new MethodNotAllowedException(Core.Resources.DeleteVersionNotAllowed);
            }

            ResourceWrapper currentDoc = await FhirDataStore.GetAsync(key, cancellationToken);
            if (currentDoc == null)
            {
                throw new ResourceNotFoundException(string.Format(Core.Resources.ResourceNotFoundById, key.ResourceType, key.Id));
            }

            var patchedResource = _patchService.Patch(currentDoc, request.PatchDocument, request.WeakETag);

            return await _mediator.Send<UpsertResourceResponse>(new UpsertResourceRequest(patchedResource), cancellationToken);
        }
    }
}
