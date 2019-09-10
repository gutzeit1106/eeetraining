#Import
. .\Agent.ps1
$MyAgent = [Agent]::new();

$DebugPreference = "Continue"
$wall = "※" #壁
$known = "■" #探索済み
$goal ="★" #現在地
$start ="◎" #START
$unknown = "　" #未探索の領域
$NORTH = @(0,-1)
$SOUTH = @(0,1)
$EAST = @(1,0)
$WEST = @(-1,0)
$DIRECTION = @($NORTH, $SOUTH, $EAST, $WEST)

function Make-Maze(){ 
  1..$height | % { $script:MAZE += ( (Make-Line).ToString() ); }

  if($script:MyAgent.state -eq 0){
      $script:ISGOAL = $true
      $cell = $script:goal
  }else{
      $script:ISGOAL = $false
      $cell = $script:start
      $ROUTE_STACK.push(@($script:x,$script:y))
  }
  $script:MAZE =  Replace-Cell $script:MAZE $script:x $script:y $cell
  $script:DISP =  $script:MAZE
  $script:DISP += "AGENT_ID  :  $($script:MyAgent.id)"
  $script:DISP += "GENERATION:  $script:GENERATION"
  $script:DISP += "API_CALL: $($script:MyAgent.api_call)"
  $script:DISP += "GOAL      : (?,?)"
  $script:DISP += "Starting..."
  $RUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates -ArgumentList  $width, $script:DISP.Length
}

function Make-Line(){
   1..$width | % { $line += (Make-Cell) }
   return $line
}

function Make-Cell(){
   $cell = $script:unknown
   return $cell
}

function Replace-Cell([String[]] $Maze, [int] $x, [int] $y, [String] $c){
     $newline = ""
     $newMaze = $Maze
     $line = $Maze[$y]
     $newline = $line.remove($x, 1)
     $newline = $newline.insert($x, $c)
     $newMaze[$y] = $newline
     return $newMaze
}

function Get-Cell([String[]] $Maze, [int]$x, [int]$y){
     $cell = $Maze[$y].Substring($x,1)
     return $cell
}

function Get-BackDirection([int[]] $current, [int[]] $back){
    $x = $current[0] - $back[0]
    $y = $current[1] - $back[1]
    $dir = 1
    foreach($d in $DIRECTION){
        if($x -eq $d[0] ){
            if($x -eq $d[0] ){
                return $dir
            }
        }
        $dir += 1
    }
}

function Display-Maze(){
  $RUI.SetBufferContents($ZERO, $RUI.NewBufferCellArray($script:DISP, 'White', 'Black'))
}

function Explore-Maze()
{
    $BASE = $script:MAZE
    $current = $script:ROUTE_STACK.peek()
    $ismove = $false

    #1: North(+0,+1) 
    #2: South(+0,-1)
    #3: East(+1, +0)
    #4: West(-1, +0)
    #Write-host "--------debug--------"
    #Write-host $script:ROUTE_STACK.Count
    $dir = 1
    foreach($d in $script:DIRECTION){
        #Write-host "--------dir--------"
        $next = @(($current[0] + $d[0]), ($current[1] + $d[1])) 
        $next_cell = Get-Cell $script:MAZE $next[0] $next[1]
        $cell = $next_cell
        #Write-host "dir:"$d
        #Write-host "Current:"$current
        #Write-host "Next:"$next
        #Write-host "next_cell:"$next_cell

        if($next_cell -in @($script:unknown)){
            $result = $script:MyAgent.Move($dir)
            #Write-host $script:MyAgent.state
            if($script:MyAgent.finalStatusCode -in @('200')){
                #Move
                $script:ROUTE_STACK.push($next)
                $ismove = $true
                if($script:MyAgent.state -eq 0){
                    $script:ISGOAL = $true
                    $cell = $script:goal
                }else{
                    $script:ISGOAL = $false
                    $cell = $script:known
                }
                $BASE = Replace-Cell $BASE $next[0] $next[1] $cell
                break;
            }elseif($script:MyAgent.finalStatusCode -in @('500')){
                #Wall
                $script:ISGOAL = $false
                $cell = $script:wall
                $BASE = Replace-Cell $BASE $next[0] $next[1] $cell
            }   
        }
        $dir += 1
    }

    #移動できる場所がなかったら戻る
    if(!$ismove){
        $current = $script:ROUTE_STACK.POP()
        $back = $script:ROUTE_STACK.Peek()
        $back_direction = Get-BackDirection $current $back
        $result = $script:MyAgent.Move($back_direction)
    }

    #GOAL
    $NEXT_DISP = $BASE
    $GOAL_MESSEAGE = "GOAL      : (?,?)"
    $STATUS_MESSEAGE = "Running..."
    if($script:ISGOAL){
        $GOAL_MESSEAGE = "GOAL      : ($($next[0]), $($next[1]))"
        $STATUS_MESSEAGE = "Finish!!"
    }

    $script:MAZE = $NEXT_DISP
    $script:GENERATION += 1
    $NEXT_DISP += "AGENT_ID  : $($script:MyAgent.id)"
    $NEXT_DISP += "GENERATION: $script:GENERATION"
    $NEXT_DISP += "API_CALL: $($script:MyAgent.api_call)"
    $NEXT_DISP += $GOAL_MESSEAGE
    $NEXT_DISP += $STATUS_MESSEAGE
    $script:DISP = $NEXT_DISP
}

# MAIN
$ZERO   = New-Object System.Management.Automation.Host.Coordinates -ArgumentList 0, 0
Clear-Host

#Maze Size
$height = 60
$width = $height
[int]$x = $width/2
[int]$y = $height/2
$RUI = $host.UI.RawUI
$MAZE = @()   #探索済みリスト
$DISP = @()   # 表示する画面文字列
$ROUTE_STACK = New-Object system.collections.stack
$ROUTE_STACK.push(@(-1,-1))
$ISGOAL = $false
$GENERATION = 0   # 世代

Make-Maze  #初期化
Display-Maze #
Start-Sleep -millisecond 250 #wait time
while(!$ISGOAL){
  echo "---debug---" >> debug.txt
  $ROUTE_STACK  >> debug.txt
  Explore-Maze
  Start-Sleep -millisecond 1000 #wait time
  Display-Maze

   if($ROUTE_STACK.Count -lt 2){
       Write-host "Error. Something is wrong."
       break;
   }

}