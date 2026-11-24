import pathlib
import tempfile
import unittest
import io
import subprocess
from unittest.mock import patch

import common
import exchange
import mac_worker as mac


class BackupChecks(unittest.TestCase):
    def test_append_json_event_is_bounded(self):
        with tempfile.TemporaryDirectory() as temp:
            path = pathlib.Path(temp) / 'events.json'
            for index in range(3):
                common.append_json_event(path, {'id': index}, limit=2)
            self.assertEqual(common.read_json(path), [{'id': 1}, {'id': 2}])

    def test_named_archives_expire_at_boundary(self):
        now = 1800000000
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            def name(kind, age, seq=2):
                return f'{kind}-{now-age}-{seq}.cms'
            keep = [name('proof',15*common.DAY), name('full',40*common.DAY)]
            expired = [name('full',30*common.DAY), name('proof',7*common.DAY)]
            remain = keep+[name('full',30*common.DAY-1),name('proof',7*common.DAY-1),'recovery.cms','not-a-backup']
            for f in expired+remain:
                (root/f).touch()
            (root/name('proof',9*common.DAY)).symlink_to(root/'recovery.cms')
            self.assertEqual(common.prune(root,set(keep),30,7,now),2)
            self.assertTrue(all((root/f).exists() for f in remain))
            self.assertTrue(all(not (root/f).exists() for f in expired))
            self.assertTrue((root/name('proof',9*common.DAY)).is_symlink())

    def test_daily_boundary(self):
        boundary = common.dt.datetime(2026,11,11,3,15,tzinfo=common.BJT).timestamp()
        self.assertNotEqual(common.period(boundary-1),common.period(boundary))
        self.assertEqual(common.period(boundary),common.period(boundary+86400-1))

    def test_monitor_thresholds(self):
        now=1800000000
        full={'name':'full-new','captured':now}
        proof={'name':'proof-new','captured':now}
        manifest={'full':full,'proof':proof,'tick':now}
        ack={'pulse':{'at':now},'proof':{'name':'proof-new','at':now},'full':{'name':'full-new','at':now}}
        self.assertEqual(exchange.health(manifest,ack,now),[])
        ack['proof']={'name':'proof-old','at':now-601}
        self.assertIn('注销记录超过 10 分钟未收到异机回执',exchange.health(manifest,ack,now))
        ack['pulse']['at']=now-601
        self.assertIn('Mac mini 超过 10 分钟未连接',exchange.health(manifest,ack,now))
        manifest.update(tick=now-241,error='read failure')
        self.assertIn('云端定时任务超过 4 分钟未更新',exchange.health(manifest,ack,now))
        self.assertIn('云端备份生成失败',exchange.health(manifest,ack,now))

    def test_bad_ciphertext_cannot_replace_local_copy(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(mac,'ARCHIVES',pathlib.Path(temp)):
            name='full-1794283525-2.cms'
            target=pathlib.Path(temp)/name
            target.write_bytes(b'old')
            meta=dict(name=name,size=5,sha256='a'*64,seq=2,identity='sample',hash='b'*64,captured=1794283525)
            with patch.object(mac,'remote',side_effect=lambda *args,output: output.write(b'wrong')):
                with self.assertRaises(ValueError):
                    mac.receive(meta,{})
            self.assertEqual(target.read_bytes(),b'old')
            self.assertEqual(list(target.parent.iterdir()),[target])

    def test_low_disk_space_blocks_receive_before_download(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(mac, 'ARCHIVES', pathlib.Path(temp)):
            name='full-1794283525-2.cms'
            meta=dict(name=name,size=5,sha256='a'*64,seq=2,identity='sample',hash='b'*64,captured=1794283525)
            usage = type('Usage', (), {'free': mac.MIN_FREE_BYTES - 1})()
            with patch.object(mac.shutil, 'disk_usage', return_value=usage), patch.object(mac, 'remote') as remote:
                with self.assertRaisesRegex(OSError, '至少 20 GiB'):
                    mac.receive(meta,{})
            remote.assert_not_called()

    def test_remote_get_retries_and_truncates_partial_output(self):
        payload = b'complete'
        failures = [subprocess.CalledProcessError(1, ['ssh'], stderr=b'temporary network'),
                    subprocess.CalledProcessError(1, ['ssh'], stderr=b'temporary network')]
        def fake_remote(*args, output=subprocess.PIPE):
            if failures:
                output.write(b'partial')
                raise failures.pop(0)
            output.write(payload)
        with patch.object(mac, 'remote', side_effect=fake_remote), patch.object(mac.time, 'sleep') as sleep:
            target = io.BytesIO()
            mac.remote_get_retry('full-1794283525-2.cms', target)
        self.assertEqual(target.getvalue(), payload)
        self.assertEqual(sleep.call_count, 2)

    def test_notification_throttle_and_recovery(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(mac,'banner') as banner:
            state=pathlib.Path(temp)/'status.json'
            mac.notify(['异常'],state)
            mac.notify(['异常'],state)
            mac.notify([],state)
            mac.notify([],state)
            self.assertEqual(banner.call_count,2)
            self.assertIn('恢复',banner.call_args.args[0])

    def test_offline_alert_delivered_once_on_reconnect(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(mac,'banner') as banner:
            state=pathlib.Path(temp)/'status.json'
            incident={'at':1794283387,'issues':['Mac mini 超过 10 分钟未连接']}
            mac.notify([],state,incidents=[incident])
            mac.notify([],state,incidents=[incident])
            self.assertEqual(banner.call_count,1)
            self.assertIn('当前已恢复',banner.call_args.args[0])


if __name__=='__main__':
    unittest.main()
