﻿// -------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See LICENSE in the repo root for license information.
// -------------------------------------------------------------------------------------------------

using EnsureThat;
using MediatR;

namespace Microsoft.Health.Fhir.Core.Messages.Import
{
    public class CancelImportRequest : IRequest<CancelImportResponse>
    {
        public CancelImportRequest(string taskId)
        {
            EnsureArg.IsNotNullOrWhiteSpace(taskId, nameof(taskId));

            TaskId = taskId;
        }

        /// <summary>
        /// Import orchestrator task id
        /// </summary>
        public string TaskId { get; }
    }
}
