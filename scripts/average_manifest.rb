#!ruby

if (ARGV.size() != 2)
  exit(1)
end

sFileName = ARGV[0]
nDivNum = ARGV[1].to_i()

if (!File.exist?(sFileName))
  exit(1)
end

if (nDivNum <= 0)
  exit(1)
end

aData = File.read(sFileName).split("\n")

aYaml = []
(1..nDivNum).each{|nCnt|
  aYaml[nCnt] = []
}

nCnt = 1
aData.each{|sLine|
  aYaml[nCnt].push(sLine)
  nCnt += 1
  if (nCnt > nDivNum)
    nCnt = 1
  end
}

(1..nDivNum).each{|nCnt|
  aYaml[nCnt].each{|sLine|
    puts(sLine)
  }
}

exit(0)
