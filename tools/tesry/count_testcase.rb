#!ruby -w
#
# 引数に与えたフォルダ/ファイルから，各TESRYファイルに含まれるテストケ
# ース数をプロファイルごとにカウントする．
#

require "yaml"

if (ARGV.size() == 0)
  abort("Argument error !")
end
aTargetFile = []
ARGV.each{|sArg|
  if (FileTest.file?(sArg))
    aTargetFile.push(sArg)
  elsif (FileTest.directory?(sArg))
    aTargetFile.concat(Dir.glob("#{sArg}/**/*.yaml"))
  else
    abort("invalid argument: #{sArg}")
  end
}

nASP = 0
nFMP = 0
nHRP = 0
nHRMP = 0
aTargetFile.each{|sFilePath|
  hTesryInfo = YAML.load_file(sFilePath)
  hTesryInfo.delete("version")
  hTesryInfo.each{|sTestID, hTestScenario|
    if (sFilePath.include?("/ASP/"))
      nASP += 1
    elsif (sFilePath.include?("/FMP/"))
      nFMP += 1
    elsif (sFilePath.include?("/HRP/"))
      nHRP += 1
    elsif (sFilePath.include?("/HRMP/"))
      nHRMP += 1
    else
      abort("invalid file: #{sFilePath}")
    end
  }
}
nASPNum = nASP
nFMPNum = nASP + nFMP
nHRPNum = nASP + nHRP
nHRMPNum = nASP + nFMP + nHRP + nHRMP

puts("ASP : #{nASPNum}")
puts("FMP : #{nFMPNum}")
puts("HRP : #{nHRPNum}")
puts("HRMP: #{nHRMPNum}")
