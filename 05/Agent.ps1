$APIHost= "khiraha10:8090"
$MaxRetry = 2
$MaxTimeoutSec = 15

# �N���X��`
class Agent
{
    #Member
    [String] $id
    [String] $state
    [Boolean] $final_move
    [int] $api_call
    [String] $finalStatusCode
    [String] $finalstatusDescription

    #Constructer
    # initialize an agent 
    Agent(){
       #Initialize
       $r = APIRequest "api/agent/init" "Put"
       if ($r.StatusCode -in @('200')){
            $this.id = $r.id
            $this.state = $r.state
            $this.final_move = $r.final_move
            $this.api_call = 0
            $this.finalStatusCode = $r.StatusCode
            $this.finalstatusDescription = 'Initialize successfully'
       }else{
            $this.id = ''
            $this.state = ''
            $this.final_move = $false
            $this.api_call = 0
            $this.finalStatusCode = $r.StatusCode
            $this.finalstatusDescription = 'Initialize Error'
       }

    }

    [String] Disp(){
       return "id=" + $this.id + ",state=" + $this.state + ",final_move=" + $this.final_move + ",status=" + $this.finalStatusCode
    }

    # get the current agent id
    [String] Get(){
       $r = APIRequest "api/agent/$($this.id)" "Get"
        if ($r.StatusCode -in @('200')){
            $this.state = $r.state
            $this.final_move = $r.final_move
            $this.api_call += 1
            $this.finalStatusCode = $r.StatusCode
            $this.finalstatusDescription = 'Get the agent current state successfully'
       }elseif($r.StatusCode -in @('404')){
            $this.state = $r.state
            $this.final_move = $r.final_move
            $this.api_call += 1
            $this.finalStatusCode = $r.StatusCode
            $this.finalstatusDescription = "Unknown Agent ID:$($this.id)"
       }else{
            $this.state = $r.state
            $this.final_move = $r.final_move
            $this.api_call += 1 
            $this.finalStatusCode = $r.StatusCode
            $this.finalstatusDescription = 'Unknown Error. Please retry later.' 
       }
       return "id=" + $this.id + ",state=" + $this.state + ",final_move=" + $this.final_move + ",finalStatusCode=" + $this.finalStatusCode + ",finalstatusDescription=" + $this.finalstatusDescription 
    }

    # move (north:1,south:2, east:3,west:4)
    [String] Move([int] $Direction){
       $dirct_uri = ""
       switch($Direction){
         1{ $dirct_uri = "move/north";break;}
         2{ $dirct_uri = "move/south";break;}
         3{ $dirct_uri = "move/east";break;}
         4{ $dirct_uri = "move/west";break;}
         default{return "Dorection Number is wrong.(YourNumber=$Direction. please choose north:1, south:2, east:3, west:4)"}
       }
       
       $r = APIRequest "api/agent/$($this.id)/$dirct_uri" "Put"
       if ($r.StatusCode -in @('200')){
            $this.state = $r.state
            $this.final_move = $r.final_move
            $this.api_call += 1
            $this.finalStatusCode = $r.StatusCode
            $this.finalstatusDescription = ""
       }elseif ($r.StatusCode -in @('404')){
            $this.state = $r.state
            $this.final_move = $r.final_move
            $this.api_call += 1
            $this.finalStatusCode = $r.StatusCode
            $this.finalstatusDescription = "Unknown Agent ID:$($this.id)"
       }elseif ($r.StatusCode -in @('500')){
            $this.state = $r.state
            $this.final_move = $r.final_move
            $this.api_call += 1
            $this.finalStatusCode = $r.StatusCode
            $this.finalstatusDescription = "Bad Direction"
       }
      return "id=" + $this.id + ",state=" + $this.state + ",final_move=" + $this.final_move + ",finalStatusCode=" + $this.finalStatusCode + ",finalstatusDescription=" + $this.finalstatusDescription 
    }
}
function TestFunction(){
    Write-Host "This is test."
}

function APIRequest([String] $URI, [String] $Method){
    $try = $script:MaxRetry
    $date = Get-Date -Format "yyyy-MMdd-HHmmss"
    #Write-Host '---------------------'
    #Write-Host $date.ToString()", $URI, $Method"
    while($true){
        try {
            $full_uri = "http://$($script:APIHost)/$URI"
            $r = Invoke-RestMethod -Method $Method -Uri $full_uri -TimeoutSec $script:MaxTimeoutSec
            $result = FormatObject '200' $null $r
            $date.ToString() + ", $full_uri, $Method, 200, $r" >> ./log.txt
            #Write-Host "StatusCode:200"
            break

        }catch{  
            $date.ToString() + ", $full_uri, $Method," + $_.Exception   >> ./log.txt
            #Write-Host "StatusCode:" $_.Exception
            #Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__
            #Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription]

            if($URI.Contains("move")){
                if($_.Exception.Response.StatusCode.value__ -in @("404", "500")){

                    $result = FormatObject $_.Exception.Response.StatusCode.value__ $_.Exception.Response.StatusDescription $null
                    return $result
                }
            }
            #client error
            if($_.Exception.Response.StatusCode.value__ -in @("400,401,402,403,404,405")){
                    $result = FormatObject $_.Exception.Response.StatusCode.value__ $_.Exception.Response.StatusDescription $null
                    return $result
            }

            #server error
            if($_.Exception.Response.StatusCode.value__ -in @("500,501,502,503,505")){
                    $result = FormatObject $_.Exception.Response.StatusCode.value__ $_.Exception.Response.StatusDescription $null
                    return $result
            }
        }
        $try += -1;
        if($try -lt 1){break;}
    }  
    return $result
}

function FormatObject ([String]$StatusCode, [String]$StatusDescription, $obj)
{
    $p = new-object PSObject
    $p | Add-Member -Name StatusCode -TypeName String -Value $StatusCode -MemberType NoteProperty 

    if ($StatusDescription -ne $null){
        $p | Add-Member -Name StatusDescription -TypeName String -Value $StatusDescription  -MemberType NoteProperty 
    }else{
        $p | Add-Member -Name StatusDescription -TypeName String -Value '' -MemberType NoteProperty 
    }

    if ($obj -ne $null){
        $p | Add-Member -Name id -TypeName String -Value $obj.id  -MemberType NoteProperty 
        $p | Add-Member -Name state -TypeName Boolean -Value $obj.state  -MemberType NoteProperty 
        $p | Add-Member -Name final_move -TypeName String -Value $obj.final_move  -MemberType NoteProperty
    }
    return $p

}