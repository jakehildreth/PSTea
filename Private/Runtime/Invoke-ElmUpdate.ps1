function Invoke-ElmUpdate {
    <#
    .SYNOPSIS
        Deep-copies the current model then calls the user-supplied Update function.

    .DESCRIPTION
        Follows the TEA/MVU Update step: `update msg model -> (model, cmd)`.

        Performs a deep copy of the model via Copy-ElmModel before passing it to
        the Update function so that the original model is never mutated. The Update
        function receives the message as the first positional argument and the model
        copy as the second.

        The Update function must return a PSCustomObject with two properties:
          - Model: the new model state
          - Cmd:   a command object, or $null for no command

    .PARAMETER UpdateFn
        A scriptblock that implements the Update step. Signature:
            { param($Message, $Model) ... return [PSCustomObject]@{ Model = ...; Cmd = ... } }

    .PARAMETER Message
        The message (event) to process. May be any type - the Update function
        determines how to handle it.

    .PARAMETER Model
        The current model. A deep copy is passed to the Update function.

    .OUTPUTS
        [PSCustomObject] - Object with Model and Cmd properties as returned by UpdateFn.

    .EXAMPLE
        $updateFn = {
            param($msg, $model)
            $newModel = [PSCustomObject]@{ Count = $model.Count + 1 }
            [PSCustomObject]@{ Model = $newModel; Cmd = $null }
        }
        $result = Invoke-ElmUpdate -UpdateFn $updateFn -Message 'Increment' -Model $model
        $result.Model.Count

    .NOTES
        The Cmd return value is inspected by Invoke-ElmEventLoop to determine whether
        to schedule side effects or stop the event loop.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$UpdateFn,

        [Parameter(Mandatory)]
        [AllowNull()]
        $Message,

        [Parameter(Mandatory)]
        $Model
    )

    $modelCopy = Copy-ElmModel -Model $Model
    $result = & $UpdateFn $Message $modelCopy
    return $result
}
