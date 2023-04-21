// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.
permissionset 82660 "RSMUS BC-2-ODS Setup"
{
    /// <summary>
    /// The permission set to be used when administering the Azure Data Lake Storage export tool.
    /// </summary>
    Access = Public;
    Assignable = true;
    Caption = 'Win-Waste BC-2-ODS Process - Setup';

    Permissions = tabledata "RSMUS Setup" = RIMD,
                  tabledata "RSMUS Table" = RIMD,
                  tabledata "RSMUS Field" = RIMD,
                  tabledata "RSMUS Deleted Record" = RD,
                  tabledata "RSMUS Current Session" = R,
                  tabledata "RSMUS Table Tracking" = RID,
                  tabledata "RSMUS Runs Log" = RID,
                  tabledata "RSMUS Detailed Runs Log" = RID;
}