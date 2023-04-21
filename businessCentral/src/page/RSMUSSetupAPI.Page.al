// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
page 82664 "RSMUS Setup API"
{
    PageType = API;
    APIPublisher = 'bc2adlsTeamMicrosoft';
    APIGroup = 'bc2adls';
    APIVersion = 'v1.0';
    EntityName = 'adlseSetup';
    EntitySetName = 'adlseSetup';
    SourceTable = "RSMUS Setup";
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    ODataKeyFields = SystemId;

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field(primaryKey; Rec."Primary Key") { }
                field(container; Rec.Container) { }
                field(emitTelemetry; Rec."Emit telemetry") { }
                field(dataFormat; Rec.DataExportFormat) { }
                field(maxPayloadSizeMiB; Rec.MaxPayloadSizeMiB) { }
                field(multiCompanyExport; Rec."Multi- Company Export") { }
                field(systemId; Rec.SystemId)
                {
                    Editable = false;
                }
                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Editable = false;
                }
            }
        }
    }

    [ServiceEnabled]
    procedure StartExport(var ActionContext: WebServiceActionContext)
    var
        rsmusExecution: Codeunit "RSMUS Execution";
    begin
        rsmusExecution.StartExport();
        SetActionResponse(ActionContext, Rec."SystemId");
    end;

    [ServiceEnabled]
    procedure StopExport(var ActionContext: WebServiceActionContext)
    var
        rsmusExecution: Codeunit "RSMUS Execution";
    begin
        rsmusExecution.StopExport();
        SetActionResponse(ActionContext, Rec."SystemId");
    end;

    local procedure SetActionResponse(var ActionContext: WebServiceActionContext; AdlsId: Guid)
    var
    begin
        SetActionResponse(ActionContext, Page::"RSMUS Setup API", AdlsId);
    end;

    local procedure SetActionResponse(var ActionContext: WebServiceActionContext; PageId: Integer; DocumentId: Guid)
    var
    begin
        ActionContext.SetObjectType(ObjectType::Page);
        ActionContext.SetObjectId(PageId);
        ActionContext.AddEntityKey(Rec.FieldNo(SystemId), DocumentId);
        ActionContext.SetResultCode(WebServiceActionResultCode::Updated);
    end;
}