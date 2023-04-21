// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License. See LICENSE in the project root for license information.

/// <summary>
/// The formats in which data is stored on the data lake
/// </summary>
enum 82662 "RSMUS Data Export Format"
{
    Extensible = false;

    value(0; "CSV")
    {
        Caption = 'CSV';
    }
    value(1; "JSON")
    {
        Caption = 'JSON';
    }
    value(2; Parquet)
    {
        Caption = 'Parquet';
    }
}