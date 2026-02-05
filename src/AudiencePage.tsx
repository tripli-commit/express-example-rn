import React, { useEffect, useRef, useState } from 'react';
import { findNodeHandle, Image, StyleSheet, TouchableOpacity, View, LayoutChangeEvent, Text, Dimensions } from 'react-native';
import Toast from 'react-native-root-toast';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useFocusEffect, useNavigation, useRoute } from '@react-navigation/native';
import ZegoExpressEngine, {ZegoPublishChannel, ZegoTextureView, ZegoUpdateType, ZegoStream} from 'zego-express-engine-reactnative';

import PipModuleHelper from './PipModuleHelper';
import StreamHelper from './StreamHelper';

const Audience: React.FC = () => {
  const TAG = 'Audience'

  const navigation = useNavigation();

  const { params } = useRoute();
  const { roomID, userID } = params;
  
  // 维护房间内的流列表
  const [streamList, setStreamList] = useState<ZegoStream[]>([]);
  // 显示前4条流
  const [displayStreams, setDisplayStreams] = useState<ZegoStream[]>([]);
  // 选中的流索引 (-1 表示未选中)
  const [selectedStreamIndex, setSelectedStreamIndex] = useState<number>(-1);
  
  // 为每个流创建一个 ref
  const streamRefs = useRef<Array<ZegoTextureView | null>>([null, null, null, null]);
  const previewTextureRef = useRef<ZegoTextureView | null>(null);
  const [isShowTopButton, setIsShowTopButton] = useState(true);
  const [isPreviewVisible, setIsPreviewVisible] = useState(false);

  useFocusEffect(
    React.useCallback(() => {
      console.log(`${TAG} is focused`);
      PipModuleHelper.notifyPagePipEnable(true, TAG)
      PipModuleHelper.registerPipModeChangedListener(TAG, (data) => {
        if (typeof data === 'boolean') {
          setIsShowTopButton(!data)
        }
      })

      return () => {
        console.log(`${TAG} is unfocused`);
        // @ts-ignore
        PipModuleHelper.registerPipModeChangedListener(TAG, null)
      };
    }, [])
  );

  // 更新要显示的流列表(前4条)
  useEffect(() => {
    const streamsToDisplay = streamList.slice(0, 4);
    setDisplayStreams(streamsToDisplay);
    
    // 为每个显示的流启动拉流
    streamsToDisplay.forEach((stream, index) => {
      setTimeout(() => {
        const viewRef = streamRefs.current[index];
        if (viewRef) {
          console.log(TAG, `startPlayingStream for stream ${index}: ${stream.streamID}`);
          StreamHelper.startPlayingStream(stream.streamID, findNodeHandle(viewRef));
        }
      }, 100);
    });

    // 停止不再显示的流
    for (let i = streamsToDisplay.length; i < 4; i++) {
      if (streamList[i]) {
        console.log(TAG, `stopPlayingStream for index ${i}`);
        StreamHelper.stopPlayingStream(streamList[i].streamID);
      }
    }
  }, [streamList]);

  useEffect(() => {
    console.log(TAG, `loginRoom, room:${roomID}, userID:${userID}`);
    
    // 注册流更新回调 - 监听房间内流的增加和删除
    const streamUpdateListener = ZegoExpressEngine.instance().on(
      'roomStreamUpdate',
      (roomID: string, updateType: ZegoUpdateType, streamList: ZegoStream[]) => {
        console.log(TAG, `roomStreamUpdate, room:${roomID}, updateType:${updateType}, streamCount:${streamList.length}`);
        
        if (updateType === ZegoUpdateType.Add) {
          // 流增加
          console.log(TAG, 'Streams added:', streamList.map(s => s.streamID).join(', '));
          setStreamList(prevList => {
            // 避免重复添加
            const newStreams = streamList.filter(
              newStream => !prevList.some(existStream => existStream.streamID === newStream.streamID)
            );
            return [...prevList, ...newStreams];
          });
        } else if (updateType === ZegoUpdateType.Delete) {
          // 流删除
          console.log(TAG, 'Streams deleted:', streamList.map(s => s.streamID).join(', '));
          setStreamList(prevList => 
            prevList.filter(
              existStream => !streamList.some(delStream => delStream.streamID === existStream.streamID)
            )
          );
        }
      }
    );

    // 登录房间 - 使用随机生成的 UserID
    ZegoExpressEngine.instance().loginRoom(
      roomID, 
      {
        "userID": userID, 
        "userName": userID
      }, 
      undefined
    ).then((loginResult) => {
      if (loginResult.errorCode != 0 && loginResult.errorCode != 1002001) {
        console.error(TAG, `loginRoom failed, errorCode:${loginResult.errorCode}, message:${loginResult.extendedData}`)
        Toast.show(`Failed to login the room, errorCode: ${loginResult.errorCode}.`, {
          duration: Toast.durations.LONG,
          position: Toast.positions.CENTER,
        });
        return
      }

      console.log(TAG, `loginRoom success with userID: ${userID}`);
    });

    return () => {
      // 清理监听器
      if (streamUpdateListener) {
        ZegoExpressEngine.instance().off('roomStreamUpdate', streamUpdateListener);
      }
    }
  }, []);

  const onClickBack = () => {
    if (isPreviewVisible) {
      ZegoExpressEngine.instance().stopPreview(ZegoPublishChannel.Main);
    }
    
    // 停止所有正在播放的流
    displayStreams.forEach(stream => {
      StreamHelper.stopPlayingStream(stream.streamID);
    });
    
    ZegoExpressEngine.instance().logoutRoom(roomID);
    console.log(TAG, `logoutRoom, room:${roomID}`);
  
    navigation.goBack()
  };

  const onClickPreview = () => {
    setIsPreviewVisible(prev => !prev);
    if (!isPreviewVisible) {
      // 显示预览时,启动本端预览
      setTimeout(() => {
        StreamHelper.startPreview(findNodeHandle(previewTextureRef.current))
      }, 100);
    } else {
      // 隐藏预览,停止本端预览
      StreamHelper.stopPreview()
    }
  };

  const insets = useSafeAreaInsets();
  const screenWidth = Dimensions.get('window').width;
  const screenHeight = Dimensions.get('window').height;

  // 处理流视图点击
  const onStreamViewClick = (index: number) => {
    if (!displayStreams[index]) {
      // 空位不响应点击
      return;
    }
    
    if (selectedStreamIndex === index) {
      // 二次点击同一个 view，取消选中
      setSelectedStreamIndex(-1);
      StreamHelper.configPipModeRendering(null, null);
      console.log(TAG, `Deselected stream at index ${index}, cleared PIP streamID and rendering`);
    } else {
      // 选中当前 view
      const streamID = displayStreams[index].streamID;
      const viewRef = streamRefs.current[index];
      setSelectedStreamIndex(index);
      
      if (viewRef) {
        const reactTag = findNodeHandle(viewRef);
        StreamHelper.configPipModeRendering(streamID, reactTag);
        console.log(TAG, `Selected stream at index ${index}: ${streamID}, configured PIP rendering with reactTag: ${reactTag}`);
      } else {
        console.warn(TAG, `View ref not found for index ${index}`);
      }
    }
  };

  // 渲染单个流视图
  const renderStreamView = (stream: ZegoStream | undefined, index: number) => {
    const isSelected = selectedStreamIndex === index;
    if (!stream) {
      return (
        <View key={`empty-${index}`} style={styles.gridItem}>
          <View style={styles.emptyView}>
            <Text style={styles.emptyText}>Waiting</Text>
          </View>
        </View>
      );
    }

    return (
      <TouchableOpacity 
        key={stream.streamID} 
        style={styles.gridItem}
        onPress={() => onStreamViewClick(index)}
        activeOpacity={0.8}
      >
        <ZegoTextureView
          ref={(ref) => { streamRefs.current[index] = ref; }}
          style={styles.streamView}
        />
        <View style={styles.streamInfo}>
          <Text style={styles.streamText} numberOfLines={1}>
            {stream.streamID}
          </Text>
        </View>
        {/* 选中标记 - 右下角绿色小勾 */}
        {isSelected && (
          <View style={styles.checkMarkContainer}>
            <View style={styles.checkMark}>
              <Text style={styles.checkMarkText}>✓</Text>
            </View>
          </View>
        )}
      </TouchableOpacity>
    );
  };

  return (
    <View style={styles.container}>
      {/* 2x2 网格布局 */}
      <View style={styles.gridContainer}>
        <View style={styles.gridRow}>
          {renderStreamView(displayStreams[0], 0)}
          {renderStreamView(displayStreams[1], 1)}
        </View>
        <View style={styles.gridRow}>
          {renderStreamView(displayStreams[2], 2)}
          {renderStreamView(displayStreams[3], 3)}
        </View>
      </View>
      
      {/* 预览窗口 - 仅在预览时可见,位于右下角 */}
      {isPreviewVisible && (
        <ZegoTextureView 
          ref={previewTextureRef} 
          style={styles.previewView} 
        />
      )}

      {/* 顶部按钮栏 */}
      { isShowTopButton ? <View style={[styles.top_btn_container, {top: insets.top}]}>
        <TouchableOpacity style={styles.backBtnPos} onPress={onClickBack}>
          <Image 
            style={styles.backBtnImage} 
            source={require('./resources/icon_nav_back.png')}
          />
        </TouchableOpacity>

        <TouchableOpacity style={styles.previewBtnPos} onPress={onClickPreview}>
          <Image 
            style={styles.previewBtnImage}
            source={require('./resources/icon_preview.png')}
          />
        </TouchableOpacity>
        
        {/* 显示流数量信息 */}
        <View style={styles.streamCountContainer}>
          <Text style={styles.streamCountText}>
            流: {displayStreams.length}/{streamList.length}
          </Text>
        </View>
      </View> : null }
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    flexDirection: 'column',
    backgroundColor: 'black',
  },
  gridContainer: {
    flex: 1,
    flexDirection: 'column',
  },
  gridRow: {
    flex: 1,
    flexDirection: 'row',
  },
  gridItem: {
    flex: 1,
    margin: 1,
    backgroundColor: '#1a1a1a',
    justifyContent: 'center',
    alignItems: 'center',
  },
  streamView: {
    width: '100%',
    height: '100%',
  },
  emptyView: {
    width: '100%',
    height: '100%',
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#2a2a2a',
  },
  emptyText: {
    color: '#666',
    fontSize: 14,
  },
  streamInfo: {
    position: 'absolute',
    bottom: 5,
    left: 5,
    right: 5,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  streamText: {
    color: 'white',
    fontSize: 12,
  },
  top_btn_container: {
    position: 'absolute',
    flexDirection: 'row',
    top: 0,
    left: 0,
    right: 0,
    height: 40,
    zIndex: 1,
    alignItems: 'center',
  },
  backBtnPos: {
    marginLeft: 15,
    width: 20,
    height: 20,
  },
  backBtnImage: {
    width: 20,
    height: 20,
  },
  previewBtnPos: {
    marginLeft: 20,
    width: 20,
    height: 20,
  },
  previewBtnImage: {
    width: 20,
    height: 20,
  },
  streamCountContainer: {
    marginLeft: 20,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 4,
  },
  streamCountText: {
    color: 'white',
    fontSize: 12,
  },
  previewView: {
    position: 'absolute',
    bottom: 20,
    right: 20,
    width: 120,
    height: 160,
    borderWidth: 2,
    borderColor: 'white',
    borderRadius: 8,
  },
  checkMarkContainer: {
    position: 'absolute',
    bottom: 5,
    right: 5,
    zIndex: 10,
  },
  checkMark: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#00d846',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.3,
    shadowRadius: 3,
    elevation: 5,
  },
  checkMarkText: {
    color: 'white',
    fontSize: 16,
    fontWeight: 'bold',
  },
});

export default Audience;