import React, { useEffect, useRef, useState } from 'react';
import { findNodeHandle, Image, StyleSheet, TouchableOpacity, View, LayoutChangeEvent } from 'react-native';
import Toast from 'react-native-root-toast';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useFocusEffect, useNavigation, useRoute } from '@react-navigation/native';
import ZegoExpressEngine, {ZegoPublishChannel, ZegoTextureView} from 'zego-express-engine-reactnative';

import PipModuleHelper from './PipModuleHelper';
import StreamHelper from './StreamHelper';

const Audience: React.FC = () => {
  const TAG = 'Audience'

  const navigation = useNavigation();

  const { params } = useRoute();
  const { roomID, userID, hostStreamID } = params;
  
  const playingTextureRef = useRef<ZegoTextureView | null>(null);
  const previewTextureRef = useRef<ZegoTextureView | null>(null);
  const [isShowTopButton, setIsShowTopButton] = useState(true);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [rebindOnLayout, setRebindOnLayout] = useState(false);
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

  useEffect(() => {
    console.log(TAG, `loginRoom, room:${roomID}, userID:${userID}`);
    ZegoExpressEngine.instance().loginRoom(
      roomID, {"userID": userID, "userName": "Audience"}, undefined
    ).then((loginResult) => {
      if (loginResult.errorCode != 0 && loginResult.errorCode != 1002001) {
        console.error(TAG, `loginRoom, result:${loginResult.errorCode}, message:${loginResult.extendedData}`)
        Toast.show(`Failed to login the room, errorCode: ${loginResult.errorCode}.`, {
          duration: Toast.durations.LONG,
          position: Toast.positions.CENTER,
        });

        return
      }

      console.log(TAG, 'startPlayingStream')
      StreamHelper.setIosPipStreamID(hostStreamID)
      StreamHelper.startPlayingStream(hostStreamID, findNodeHandle(playingTextureRef.current));
    });

    return () => {
    }
  }, []);

  const onClickBack = () => {
    if (isPreviewVisible) {
      ZegoExpressEngine.instance().stopPreview(ZegoPublishChannel.Main);
    }
    StreamHelper.stopPlayingStream(hostStreamID);
    StreamHelper.setIosPipStreamID('')
    ZegoExpressEngine.instance().logoutRoom(roomID);
    console.log(TAG, `logoutRoom, room:${roomID}`);
  
    navigation.goBack()
  };

  const onClickResize = () => {
    setIsFullscreen(prev => {
      setRebindOnLayout(true);
      return !prev;
    });
  };

  const onClickPreview = () => {
    setIsPreviewVisible(prev => !prev);
    if (!isPreviewVisible) {
      // 显示预览时，启动本端预览
      setTimeout(() => {
        StreamHelper.startPreview(findNodeHandle(previewTextureRef.current))
      }, 100);
    } else {
      // 隐藏预览，停止本端预览
      StreamHelper.stopPreview()
    }
  };

  const onTextureLayout = (event: LayoutChangeEvent) => {
    if (rebindOnLayout) {
      setRebindOnLayout(false);
      StreamHelper.startPlayingStream(hostStreamID, findNodeHandle(playingTextureRef.current));
    }
  };

  const insets = useSafeAreaInsets();

  return (
    <View style={styles.container}>
      <ZegoTextureView
        ref={playingTextureRef} 
        style={isFullscreen ? styles.fullscreenView : styles.centeredView} 
        onLayout={onTextureLayout}
      />
      
      {/* 预览窗口 - 仅在预览时可见，位于右下角 */}
      {isPreviewVisible && (
        <ZegoTextureView 
          ref={previewTextureRef} 
          style={styles.previewView} 
        />
      )}

      { isShowTopButton ? <View style={[styles.top_btn_container, {top: insets.top}]}>
        <TouchableOpacity style={styles.backBtnPos} onPress={onClickBack}>
          <Image 
            style={styles.backBtnImage} 
            source={require('./resources/icon_nav_back.png')} // 替换为你的图片路径
          />
        </TouchableOpacity>

        <TouchableOpacity style={styles.resizeBtnPos} onPress={onClickResize}>
          <Image 
            style={styles.resizeBtnImage}
            source={require('./resources/icon_minimize.png')} // 替换为你的图片路径
          />
        </TouchableOpacity>

        <TouchableOpacity style={styles.previewBtnPos} onPress={onClickPreview}>
          <Image 
            style={styles.previewBtnImage}
            source={require('./resources/icon_preview.png')} // 替换为你的图片路径
          />
        </TouchableOpacity>
      </View> : null }
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    flexDirection: 'column',
    backgroundColor: 'black',
    justifyContent: 'center'
  },
  fullscreenView: {
    flex: 1,
    backgroundColor: 'black',
  },
  centeredView: {
    alignSelf: 'stretch',
    width: '100%',
    height: '60%'
  },
  top_btn_container: {
    position: 'absolute',
    flexDirection: 'row',
    top: 0,
    left: 0,
    height: 40,
    zIndex: 1,
  },
  backBtnPos: {
    top: 10,
    left: 15,
    width: 20,
    height: 20,
  },
  backBtnImage: {
  },
  resizeBtnPos: {
    top: 10,
    marginLeft: 50,
    width: 20,
    height: 20,
  },
  resizeBtnImage: {
  },
  previewBtnPos: {
    top: 10,
    marginLeft: 20,
    width: 20,
    height: 20,
  },
  previewBtnImage: {
  },
  previewView: {
    position: 'absolute',
    bottom: 20,
    right: 20,
    width: 180,
    height: 320,
    borderWidth: 1,
    borderColor: 'white',
  },
});

export default Audience;