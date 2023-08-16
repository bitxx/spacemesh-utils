#!/bin/bash


echo "请输入节点名称(自定义名称，方便标明理解)："
read -r nodeName
if [[ -z $nodeName ]];then
    echo "节点名称不得为空";
    exit 1;
fi

echo "请输入node id（请根据官方教程去查阅获取方式）："
read -r nodeId
if [[ -z $nodeId ]];then
    echo "node id 不得为空";
    exit 1;
fi

echo "请输入commitment atx id（请根据官方教程去查阅获取方式）："
read -r commitmentAtxId
if [[ -z $commitmentAtxId ]];then
    echo "commitment atx id 不得为空";
    exit 1;
fi

echo "请输入数据存储位置（就是post_data位置，里面应该有两个文件，xx.json和key）："
read -r commitmentAtxId
if [[ -z $commitmentAtxId ]];then
    echo "数据存储位置不得为空";
    exit 1;
fi

echo "请输入总共需要P的空间(GB，整数)："
read -r desiredSizeGiB
if [[ -z $desiredSizeGiB ]];then
    echo "总空间空间不得为空";
    exit 1;
fi
if [[ $desiredSizeGiB -le 0 ]];then
  echo "总空间需要大于0的整数，单位为G";
  exit 1;
fi

echo "请输入每个文件大小(GB，整数)："
read -r maxFileSizeGiB
if [[ -z $maxFileSizeGiB ]];then
    echo "每个文件大小不得为空";
    exit 1;
fi
if [[ $desiredSizeGiB -le 0 ]];then
  echo "文件大小需要大于0的整数，单位为G";
  exit 1;
fi

## Automatic Values
desiredSizeGiB=$((desiredSizeGiB + 0))
maxFileSizeGiB=$((maxFileSizeGiB + 0))
numGpus=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
numGpus=$((numGpus + 0)) # convert to int
numUnits=$((desiredSizeGiB / 64))           # 64 GiB per unit
numUnits=$((numUnits + 0))                  # convert to int
maxFileSize=$((maxFileSizeGiB * 1024 * 1024 * 1024))

if [[ $desiredSizeGiB%64 -ne 0 ]];then
  echo "所选总空间无法被64整除";
  exit 1;
fi

if [[ $desiredSizeGiB%$maxFileSizeGiB -ne 0 ]];then
  echo "所选总空间无法被文件大小整除";
  exit 1;
fi

totalFiles=$((desiredSizeGiB/maxFileSizeGiB))
if [[ $totalFiles -le 0 ]];then
  echo "总文件数需要大于0";
  exit 1;
fi

avgGpuNum=$((totalFiles / numGpus))
extentGpuNum=$((totalFiles % numGpus))
maxFileSize=$((maxFileSizeGiB*1024*1024*1024))


echo "节点名称：""$nodeName"
echo "数据存储位置：""$datadir"
echo "nodeId：""$nodeId"
echo "commitmentAtxId：""$commitmentAtxId"
echo "总空间(GB)："$desiredSizeGiB
echo "单文件大小(GB)："$maxFileSizeGiB
echo "单文件大小(bit)："$maxFileSize
echo "GPU总数："$numGpus
echo "总单元数："$numUnits
echo "总文件数："$totalFiles
echo "默认平均每台GPU分配的文件数："$avgGpuNum
echo "未能平均分配到GPU的文件数："$extentGpuNum

read -r -p "是否确认? [Y/n] " input

case $input in
    [yY][eE][sS]|[yY])
        echo "Yes,Continue"
        ;;
    [nN][oO]|[nN])
        echo "No,Exit"
        exit 1
        ;;
    *)
        echo "Invalid input..."
        exit 1
        ;;
esac


# 如果文件无法平均分配到每台显卡，则平均值加1
if [[ $extentGpuNum -gt 0 ]];then
    avgGpuNum=$((avgGpuNum+1))
fi

# Script to run postcli for each GPU
# 当extentGpuNum为0和不为0时候的处理方式
for ((gpuIndex=0; gpuIndex<numGpus; gpuIndex++)); do
  if [[ extentGpuNum -le 0 ]] || [[ gpuIndex+1 -le extentGpuNum ]];then
    fromFile=$((gpuIndex * avgGpuNum))
    toFile=$(( (gpuIndex + 1) * avgGpuNum - 1 ))
  else
    # 未能平均分配，则除了前面每台多分配一个后，剩余的均少分配一个
    fromFile=$((gpuIndex * avgGpuNum-(gpuIndex+1-extentGpuNum-1)))
    toFile=$(( (gpuIndex + 1) * avgGpuNum - 1 -(gpuIndex+1-extentGpuNum)))
  fi
  nohup postcli -provider gpuIndex -commitmentAtxId "$commitmentAtxId" -id "$nodeId" -numUnits $numUnits -maxFileSize=$maxFileSize -datadir "$datadir" -fromFile $fromFile -toFile $toFile >"$nodeName""_""$gpuIndex"".log" &
done
