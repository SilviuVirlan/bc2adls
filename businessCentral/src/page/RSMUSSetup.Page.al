// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
page 82660 "RSMUS Setup"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "RSMUS Setup";
    InsertAllowed = false;
    DeleteAllowed = false;
    Caption = 'BC-2-ODS Setup';
    AdditionalSearchTerms = 'Win-Waste,ODS,Data Warehousing';
    layout
    {
        area(Content)
        {
            group(Setup)
            {
                Caption = 'Setup';
                group(StorageAccount)
                {
                    Caption = 'Storage Account';
                    field("Tenant ID"; StorageTenantID)
                    {
                        ApplicationArea = All;
                        Caption = 'AAD Tenant ID';
                        Tooltip = 'Specifies the tenant ID which holds the Azure app registration as well as the storage account. Note that they have to be on the same tenant.';

                        trigger OnValidate()
                        begin
                            rsmusCredentials.SetTenantID(StorageTenantID);
                        end;
                    }
                    field(AccountName; StorageAccount)
                    {
                        ApplicationArea = All;
                        Caption = 'Storage Account';
                        Tooltip = 'Specifies the name of the storage account.';

                        trigger OnValidate()
                        begin
                            rsmusCredentials.SetStorageAccount(StorageAccount);
                        end;
                    }
                    field(Container; Rec.Container)
                    {
                        ApplicationArea = All;
                        Tooltip = 'Specifies the name of the container where the data is going to be uploaded. Please refer to constraints on container names at https://docs.microsoft.com/en-us/rest/api/storageservices/naming-and-referencing-containers--blobs--and-metadata.';
                    }
                }
                group(Access)
                {
                    Caption = 'App registration';
                    field("Client ID"; ClientID)
                    {
                        Caption = 'App/Client ID';
                        ApplicationArea = All;
                        Tooltip = 'Specifies the application client ID for the Azure App Registration that accesses the storage account.';

                        trigger OnValidate()
                        begin
                            rsmusCredentials.SetClientID(ClientID);
                        end;
                    }
                    field("Client Secret"; ClientSecret)
                    {
                        Caption = 'App/Client Secret';
                        ApplicationArea = All;
                        ExtendedDatatype = Masked;
                        Tooltip = 'Specifies the client secret for the Azure App Registration that accesses the storage account.';

                        trigger OnValidate()
                        begin
                            rsmusCredentials.SetClientSecret(ClientSecret);
                        end;
                    }
                }
                group(Execution)
                {
                    Caption = 'Execution';
                    field(MaxPayloadSize; Rec.MaxPayloadSizeMiB)
                    {
                        ApplicationArea = All;
                        Tooltip = 'Specifies the maximum size of the upload for each block of data in MiBs. A large value will reduce the number of iterations to upload the data but may interfear with the performance of other processes running on this environment.';
                    }

                    field("Multi- Company Export"; Rec."Multi- Company Export")
                    {
                        ApplicationArea = All;
                        Enabled = not ExportInProgress;
                        Tooltip = 'Specifies if simultaneous exports of data from different companies in Business Central to the lake are allowed. Beware that setting this checkmark will prevent you from making any changes to the export schema. We recommend that you set this checkmark only after the last changes to the CDM schema have been exported to the lake successfully.';
                    }
                    field(MaxConcurrentExports; Rec.MaxConcurrentExports)
                    {
                        ApplicationArea = All;
                        ToolTip = 'Maximum number of concurrently running background table exports';
                    }
                    field(SplitBlobsByPayloadSize; Rec.SplitBlobsByPayloadSize)
                    {
                        ApplicationArea = All;
                        ToolTip = 'False = One blob per execution, True = One or more blobs per execution based on Max Payload Size.';
                    }
                    field("Emit telemetry"; Rec."Emit telemetry")
                    {
                        ApplicationArea = All;
                        Tooltip = 'Specifies if operational telemetry will be emitted to this extension publisher''s telemetry pipeline. You will have to configure a telemetry account for this extension first.';
                    }
                    field(DataExportFormat; Rec.DataExportFormat)
                    {
                        ApplicationArea = All;
                        ToolTip = 'Specifies the data format to use for exporting table data.';
                    }
                    field(StripJSONEscapedDblQuotes; Rec.StripJSONEscapedDblQuotes)
                    {
                        ApplicationArea = All;
                        ToolTip = 'Determines whether string values in JSON formated data have the escaped double quotes removed.';
                    }
                }
            }
            part(Tables; "RSMUS Setup Tables")
            {
                ApplicationArea = All;
                UpdatePropagation = Both;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ExportNow)
            {
                ApplicationArea = All;
                Caption = 'Export';
                Tooltip = 'Starts the export process by spawning different sessions for each table.';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Image = Start;
                Enabled = not ExportInProgress;

                trigger OnAction()
                var
                    rsmusExecution: Codeunit "RSMUS Execution";
                begin
                    rsmusExecution.StartExport();
                    CurrPage.Update();
                end;
            }

            action(StopExport)
            {
                ApplicationArea = All;
                Caption = 'Stop export';
                Tooltip = 'Tries to stop all threads that are exporting data.';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Image = Stop;

                trigger OnAction()
                var
                    rsmusExecution: Codeunit "RSMUS Execution";
                begin
                    rsmusExecution.StopExport();
                    CurrPage.Update();
                end;
            }

            action(Schedule)
            {
                ApplicationArea = All;
                Caption = 'Schedule export';
                Tooltip = 'Schedules the export process as a job queue entry.';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Image = Timesheet;

                trigger OnAction()
                var
                    rsmusExecution: Codeunit "RSMUS Execution";
                begin
                    rsmusExecution.ScheduleExport();
                end;
            }

            action(ClearDeletedRecordsList)
            {
                ApplicationArea = All;
                Caption = 'Clear tracked deleted records';
                Tooltip = 'Removes the entries in the deleted record list that have already been exported. This may have to be done periodically to free up storage space.';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Image = ClearLog;
                Enabled = TrackedDeletedRecordsExist;

                trigger OnAction()
                begin
                    Codeunit.Run(Codeunit::"RSMUS Clear Tracked Deletions");
                    CurrPage.Update();
                end;
            }

            action(ResetAllTables)
            {
                ApplicationArea = All;
                Caption = 'Reset All Tables';
                ToolTip = 'Resets all tracked tables to allow restarting the Data Lake from scratch.';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Image = ClearFilter;

                trigger OnAction()
                var
                    rsmusExecution: Codeunit "RSMUS Execution";
                begin
                    rsmusExecution.ClearLastRowVersions();
                    TrackedDeletedRecordsExist := false;
                    CurrPage.Update();
                end;
            }

            action(ShowExportedTables)
            {
                ApplicationArea = All;
                Caption = 'View Exported Tables Statistics';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                image = EntryStatistics;
                RunObject = Page "RSMUS Exported Tables Tracking";
            }
        }
    }

    trigger OnInit()
    begin
        Rec.GetOrCreate();
        rsmusCredentials.Init();
        StorageTenantID := rsmusCredentials.GetTenantID();
        StorageAccount := rsmusCredentials.GetStorageAccount();
        ClientID := rsmusCredentials.GetClientID();
        ClientSecret := rsmusCredentials.GetClientSecret();
    end;

    trigger OnAfterGetRecord()
    var
        rsmusDeletedRecord: Record "RSMUS Deleted Record";
        rsmusCurrentSession: Record "RSMUS Current Session";
        rsmusRun: Record "RSMUS Runs Log";
    begin
        ExportInProgress := rsmusCurrentSession.AreAnySessionsActive();
        TrackedDeletedRecordsExist := not rsmusDeletedRecord.IsEmpty();
        OldLogsExist := rsmusRun.OldRunsExist();
        UpdateNotificationIfAnyTableExportFailed();
    end;

    var
        rsmusCredentials: Codeunit "RSMUS Credentials";
        TrackedDeletedRecordsExist: Boolean;
        ExportInProgress: Boolean;
        [NonDebuggable]
        StorageTenantID: Text;
        [NonDebuggable]
        StorageAccount: Text;
        [NonDebuggable]
        ClientID: Text;
        [NonDebuggable]
        ClientSecret: Text;
        OldLogsExist: Boolean;
        FailureNotificationID: Guid;
        ExportFailureNotificationMsg: Label 'Data from one or more tables failed to export on the last run. Please check the tables below to see the error(s).';

    local procedure UpdateNotificationIfAnyTableExportFailed()
    var
        rsmusTable: Record "RSMUS Table";
        rsmusRun: Record "RSMUS Runs Log";
        FailureNotification: Notification;
        Status: enum "RSMUS Run State";
        LastStarted: DateTime;
        ErrorIfAny: Text[2048];
    begin
        if rsmusTable.FindSet() then
            repeat
                rsmusRun.GetLastRunDetails(rsmusTable."Table ID", Status, LastStarted, ErrorIfAny);
                if Status = "RSMUS Run State"::Failed then begin
                    FailureNotification.Message := ExportFailureNotificationMsg;
                    FailureNotification.Scope := NotificationScope::LocalScope;

                    if IsNullGuid(FailureNotificationID) then
                        FailureNotificationID := CreateGuid();
                    FailureNotification.Id := FailureNotificationID;

                    FailureNotification.Send();
                    exit;
                end;
            until rsmusTable.Next() = 0;

        // no failures- recall notification
        if not IsNullGuid(FailureNotificationID) then begin
            FailureNotification.Id := FailureNotificationID;
            FailureNotification.Recall();
            Clear(FailureNotificationID);
        end;
    end;
}