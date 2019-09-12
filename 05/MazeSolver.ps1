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
$DIRECTION_NUM = @(1,2,3,4)

function Make-Maze(){ 
  1..$height | % { $script:MAZE += ( (Make-Line).ToString() ); }
  $ROUTE_STACK.push(@($script:x,$script:y))
  $GOAL_MESSEAGE = "GOAL      : (?,?)"
  $STATUS_MESSEAGE = "Starting..."
  if($script:MyAgent.state -eq 0){
      $script:ISGOAL = $true
      $cell = $script:goal
      $GOAL_MESSEAGE = "GOAL      : ($($next[0]-$script:x_init), $($next[1]-$script:y_init))"
      $STATUS_MESSEAGE = "Finish!!"
  }else{
      $script:ISGOAL = $false
      $cell = $script:start      
  }
  $script:MAZE =  Replace-Cell $script:MAZE $script:x $script:y $cell
  $script:DISP =  $script:MAZE
  $script:DISP += "MAZE SIZE    ：$script:width × $script:height (START FROM (0, 0))"
  $script:DISP += "MARK         ：$($script:start) > START, $($script:goal) > GOAL, $($script:wall) > WALL, $($script:known) > PATH"
  $script:DISP += "AGENT_ID     ：$($script:MyAgent.id)"
  $script:DISP += "GENERATION   ：$script:GENERATION"
  $script:DISP += "API_CALL     ：$($script:MyAgent.api_call)"
　$script:DISP += $GOAL_MESSEAGE
  $script:DISP += $STATUS_MESSEAGE
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
    $x = $back[0] - $current[0]
    $y = $back[1] - $current[1]
    [int] $dnum = 1
    foreach($d in $script:DIRECTION){
        if($x -eq $d[0] ){
            if($y -eq $d[1] ){
                return $dnum
            }
        }
        $dnum += 1
    }
}

function Exexute-AfterGOAL([system.collections.stack]$route){
    $rs_array = $route.ToArray()
    [array]::Reverse($rs_array)
    $i = 1
    foreach($s in $rs_array){
        if($s[0] -gt 0){
            "#$i :$($script:x_init-$s[0]) ,$($script:y_init-$s[1])" >> ./route.txt
            $i += 1
        }
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
    $dir = 0
    $forward = $script:DIRECTION
    $forward_num = $script:DIRECTION_NUM
    $switch = $false
    foreach($d in $forward){
        $next = @(($current[0] + $d[0]), ($current[1] + $d[1])) 
        $next_cell = Get-Cell $script:MAZE $next[0] $next[1]
        $cell = $next_cell
        $f = $forward_num[$dir] 
        #Write-host "# $($script:GENERATION): $d,$f" 
        if($next_cell -in @($script:unknown)){
            $result = $script:MyAgent.Move($f)
            #Write-host $script:MyAgent.state
            if($script:MyAgent.finalStatusCode -in @('200')){
                #Move
                $script:ROUTE_STACK.push($next)
                #write-host $next
                $ismove = $true
                if($script:MyAgent.state -eq 0){
                    $script:ISGOAL = $true
                    $cell = $script:goal
                }else{
                    $script:ISGOAL = $false
                    $cell = $script:known
                }
                $BASE = Replace-Cell $BASE $next[0] $next[1] $cell
                break
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
        $GOAL_MESSEAGE = "GOAL      : ($($next[0]-$script:x_init), $($next[1]-$script:y_init))"
        $STATUS_MESSEAGE = "Finish!!"
        Exexute-AfterGOAL $script:ROUTE_STACK
    }

    $script:MAZE = $NEXT_DISP
    $script:GENERATION += 1
    $NEXT_DISP += "MAZE SIZE    ：$script:width × $script:height (START FROM (0, 0))"
    $NEXT_DISP += "MARK         ：$($script:start) > START, $($script:goal) > GOAL, $($script:wall) > WALL, $($script:known) > PATH"
    $NEXT_DISP += "AGENT_ID     ：$($script:MyAgent.id)"
    $NEXT_DISP += "GENERATION   ：$script:GENERATION"
    $NEXT_DISP += "API_CALL     ：$($script:MyAgent.api_call)"
    $NEXT_DISP += $GOAL_MESSEAGE
    $NEXT_DISP += $STATUS_MESSEAGE
    $script:DISP = $NEXT_DISP

}

# MAIN
$ZERO   = New-Object System.Management.Automation.Host.Coordinates -ArgumentList 0, 0
Clear-Host

#Maze Size
$height = 100
$width = $height
[int]$x = ($width/2)
[int]$y = ($height/2)
[int]$x_init = $x
[int]$y_init = $y
$RUI = $host.UI.RawUI
$MAZE = @()   #探索済みリスト
$DISP = @()   # 表示する画面文字列
$ROUTE_STACK = New-Object system.collections.stack
$ROUTE_STACK.push(@(-1,-1))
$ISGOAL = $false
$GENERATION = 1   # 世代

Make-Maze  #初期化
Display-Maze #
Start-Sleep -millisecond 100 #wait time
while(!$ISGOAL){
  Explore-Maze
  Start-Sleep -millisecond 100 #wait time
  Display-Maze

   if($ROUTE_STACK.Count -lt 2){
       Write-host "Error. Something is wrong."
       break;
   }
}