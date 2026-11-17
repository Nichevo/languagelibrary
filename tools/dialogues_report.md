# Dialogue scenes: review list

Source: Chinese Dialogues Podcast by Wen-Hua Teng, COERLL (The Center for Open Educational Resources and Language Learning), The University of Texas at Austin. CC BY 3.0.

Made by `python3 -m tools.dialogues` from the transcripts in tools/sources/coerll. Nothing below is in the app yet: each scene is checked in English first.

## Summary

- Dialogues: 70, lines: 548
- Lines that pass every check: 372 (67%)
- Dialogues where every line passes: 18, of which 6 use only HSK 1-2 words
- Scenes (a dialogue's usable lines from the start, 2 or more): 44
- Reply turns: 248; with two right replies: 30; with a branch into another dialogue: 11
- Reply turns still needing a second right reply (from Tatoeba later): 218

Why lines were left out:

- 李 is not a word in the checked lists: 29
- has English letters or digits: 26
- 得 has more than one reading (de2, de5, dei3): 20
- written in traditional characters: 14
- 还 has more than one reading (hai2, huan2): 12
- it can be split into words in two ways that read differently: 11
- no English line to match it: 10
- 啊 has more than one reading (a1, a2, a3, a4, a5): 8
- 谢 is not a word in the checked lists: 6
- 友 is not a word in the checked lists: 6
- 孩 is not a word in the checked lists: 5
- 纽 is not a word in the checked lists: 4
- 只 has more than one reading (zhi1, zhi3): 4
- simplified and traditional differ: 3
- 儿 is not a word in the checked lists: 3
- 空 has more than one reading (kong1, kong4): 3
- has letters or digits (《》): 3
- 英 is not a word in the checked lists: 2
- 京 is not a word in the checked lists: 1
- 朋 is not a word in the checked lists: 1
- has letters or digits (（）): 1
- 尾 is not a word in the checked lists: 1
- 昨 is not a word in the checked lists: 1
- has letters or digits (()): 1
- 淇 is not a word in the checked lists: 1

## Dialogues whose lines didn't line up

- #23: 4 Chinese lines but 2 English

## Simplified and traditional disagree (left out; the recording decides)

- d14.5: simplified and traditional differ: 有，他们的车也都是国车。 / 有，他們的車也都是美國車。
- d42.8: simplified and traditional differ: 好！明天晚上七点见。 / 好！明天晚上七點見见。
- d51.3: simplified and traditional differ: 你周末也工作吗？你不看电视吗？ / 你週末也工作嗎吗？你不看電視嗎？

## Scenes to check

For each reply turn: does each ✓ reply answer the line before it, and does the ✗ reply not answer it?

### Dialogue 1 (episode 01, up to HSK 99)

- **A**: 你好！ (Nǐ hǎo!) Hello!
- **B**: 你好! (Nǐ hǎo!) Hello!
  - ✓ 你好! Hello!
  - ✗ 他们都很好，谢谢。我爸妈也问你好。 They are both fine, thanks. My parents send their regards to you, too. (from d7.2)

### Dialogue 2 (episode 01, up to HSK 99)

- **A**: 你好吗？ (Nǐ hǎo ma?) How are you?
- **B**: 我很好。 (Wǒ hěn hǎo.) I am fine.
  - ✓ 我很好。 I am fine.
  - ✗ 你忙吗？ Are you busy? (from d2.3)
- **A**: 你忙吗？ (Nǐ máng ma?) Are you busy?
  - ✓ 你忙吗？ Are you busy?
  - ✗ 我很好。 I am fine. (from d2.2)
- **B**: 我不忙。 (Wǒ bù máng.) I am not busy.
  - ✓ 我不忙。 I am not busy.
  - ✗ 你忙吗？ Are you busy? (from d2.3)

### Dialogue 3 (episode 01, up to HSK 1)

- **A**: 你爸爸、妈妈好吗？ (Nǐ bà ba, mā ma hǎo ma?) How are your parents?
- **B**: 他们都很好。 (Tā men dōu hěn hǎo.) They are both fine.
  - ✓ 他们都很好。 They are both fine.
  - ✗ 我爸爸很忙，我妈妈不忙。你爸妈忙吗？ My father is busy; my mother is not. Are your parents busy? (from d3.4)
- **A**: 他们忙吗？ (Tā men máng ma?) Are they busy?
  - ✓ 他们忙吗？ Are they busy?
  - ✗ 他们都很好。 They are both fine. (from d3.2)
- **B**: 我爸爸很忙，我妈妈不忙。你爸妈忙吗？ (Wǒ bà ba hěn máng, wǒ mā ma bù máng. Nǐ bà mā máng ma?) My father is busy; my mother is not. Are your parents busy?
  - ✓ 我爸爸很忙，我妈妈不忙。你爸妈忙吗？ My father is busy; my mother is not. Are your parents busy?
  - ✓ 他们都很忙。 They are both busy. (from d5.5, then carries on there)
  - ✗ 他们忙吗？ Are they busy? (from d3.3)
- **A**: 他们都不忙。 (Tā men dōu bù máng.) Neither of them is busy.
  - ✓ 他们都不忙。 Neither of them is busy.
  - ✗ 我爸爸很忙，我妈妈不忙。你爸妈忙吗？ My father is busy; my mother is not. Are your parents busy? (from d3.4)

### Dialogue 4 (episode 01, up to HSK 1)

- **A**: 你妈妈好吗？ (Nǐ mā ma hǎo ma?) How is your mother?
- **B**: 她很好。你妈妈呢？ (Tā hěn hǎo. Nǐ mā ma ne?) She is fine. How about your mother?
  - ✓ 她很好。你妈妈呢？ She is fine. How about your mother?
  - ✗ 我爸爸很忙，我妈妈不忙。你爸妈忙吗？ My father is busy; my mother is not. Are your parents busy? (from d3.4)
- **A**: 她也很好。 (Tā yě hěn hǎo.) She is fine, too.
  - ✓ 她也很好。 She is fine, too.
  - ✗ 她很好。你妈妈呢？ She is fine. How about your mother? (from d4.2)

### Dialogue 5 (episode 01, up to HSK 1)

- **A**: 你哥哥、弟弟好吗？ (Nǐ gē ge, dì di hǎo ma?) How are your old and younger brothers?
- **B**: 他们都很好。你哥哥、弟弟呢？ (Tā men dōu hěn hǎo. Nǐ gē ge, dì di ne?) They are both fine. How about your old and younger brothers?
  - ✓ 他们都很好。你哥哥、弟弟呢？ They are both fine. How about your old and younger brothers?
  - ✗ 我有一个姐姐，没有妹妹。你有哥哥、弟弟吗？ I have one older sister; I don’t have younger sisters. Do you have brothers? (from d8.3)
- **A**: 他们也都很好。 (Tā men yě dōu hěn hǎo.) They are both fine, too.
  - ✓ 他们也都很好。 They are both fine, too.
  - ✗ 他们都很好。你哥哥、弟弟呢？ They are both fine. How about your old and younger brothers? (from d5.2)
- **B**: 他们忙吗？ (Tā men máng ma?) Are they busy?
  - ✓ 他们忙吗？ Are they busy?
  - ✗ 他们也都很好。 They are both fine, too. (from d5.3)
- **A**: 他们都很忙。 (Tā men dōu hěn máng.) They are both busy.
  - ✓ 他们都很忙。 They are both busy.
  - ✓ 我爸爸很忙，我妈妈不忙。你爸妈忙吗？ My father is busy; my mother is not. Are your parents busy? (from d3.4, then carries on there)
  - ✗ 他们忙吗？ Are they busy? (from d3.3)

### Dialogue 7 (episode 01, up to HSK 99)

- **A**: 你爸妈好吗？ (Nǐ bà mā hǎo ma?) How are your parents?
- **B**: 他们都很好，谢谢。我爸妈也问你好。 (Tā men dōu hěn hǎo, xiè xie. Wǒ bà mā yě wèn nǐ hǎo.) They are both fine, thanks. My parents send their regards to you, too.
  - ✓ 他们都很好，谢谢。我爸妈也问你好。 They are both fine, thanks. My parents send their regards to you, too.
  - ✗ 我爸爸很忙，我妈妈不忙。你爸妈忙吗？ My father is busy; my mother is not. Are your parents busy? (from d3.4)
- **A**: 请你谢谢他们。 (Qǐng nǐ xiè xie tā men.) Please thank them.
  - ✓ 请你谢谢他们。 Please thank them.
  - ✗ 他们也都很好。 They are both fine, too. (from d5.3)

### Dialogue 8 (episode 02, up to HSK 4)

- **A**: 你有姐妹吗？有几个？ (Nǐ yǒu jiě mèi ma? Yǒu jǐ gè?) Do you have sisters? How many do you have?
- **B**: 我没有姐姐，有一个妹妹。你呢？ (Wǒ méi yǒu jiě jie, yǒu yī gè mèi mei. Nǐ ne?) I do not have older sisters; I have one younger sister. How about you?
  - ✓ 我没有姐姐，有一个妹妹。你呢？ I do not have older sisters; I have one younger sister. How about you?
  - ✗ 是吗？你有几个哥哥？ Is that so? How many older brothers do you have? (from d17.5)
- **A**: 我有一个姐姐，没有妹妹。你有哥哥、弟弟吗？ (Wǒ yǒu yī gè jiě jie, méi yǒu mèi mei. Nǐ yǒu gē ge, dì di ma?) I have one older sister; I don’t have younger sisters. Do you have brothers?
  - ✓ 我有一个姐姐，没有妹妹。你有哥哥、弟弟吗？ I have one older sister; I don’t have younger sisters. Do you have brothers?
  - ✗ 我没有姐姐，有一个妹妹。你呢？ I do not have older sisters; I have one younger sister. How about you? (from d8.2)
- **B**: 没有。你呢？ (Méi yǒu. Nǐ ne?) No. How about you?
  - ✓ 没有。你呢？ No. How about you?
  - ✗ 我有一个姐姐，没有妹妹。你有哥哥、弟弟吗？ I have one older sister; I don’t have younger sisters. Do you have brothers? (from d8.3)
- **A**: 我也没有哥哥，我有一个弟弟。 (Wǒ yě méi yǒu gē ge, wǒ yǒu yī gè dì di.) I don’t have older brothers, either. I have one younger brother.
  - ✓ 我也没有哥哥，我有一个弟弟。 I don’t have older brothers, either. I have one younger brother.
  - ✗ 我没有姐姐，有一个妹妹。你呢？ I do not have older sisters; I have one younger sister. How about you? (from d8.2)

### Dialogue 9 (episode 02, up to HSK 99)

- **A**: 你贵姓？ (Nǐ guì xìng?) What is your honorable last name?
- **B**: 我姓王，叫王贵一。 (Wǒ xìng wáng, jiào wáng guì yī.) My last name is Wang; my name is
  - ✓ 我姓王，叫王贵一。 My last name is Wang; my name is
  - ✓ 我也姓王。 My last name is also (from d24.7, then carries on there)
  - ✗ 请叫我贵一，好吗？你贵姓？ Please call me Guiyi, OK? What is your honorable last name? (from d9.4)
- **A**: 王小姐，你好。 (Wáng xiǎo jie, nǐ hǎo.) Hello,
  - ✓ 王小姐，你好。 Hello,
  - ✗ 我姓王，叫王贵一。 My last name is Wang; my name is (from d9.2)
- **B**: 请叫我贵一，好吗？你贵姓？ (Qǐng jiào wǒ guì yī, hǎo ma? Nǐ guì xìng?) Please call me Guiyi, OK? What is your honorable last name?
  - ✓ 请叫我贵一，好吗？你贵姓？ Please call me Guiyi, OK? What is your honorable last name?
  - ✗ 小姐，你呢？ Miss, what about you? (from d53.7)

### Dialogue 12 (episode 02, up to HSK 3)

- **A**: 这是谁？是你女朋友吗？ (Zhè shì shéi? Shì nǐ nǚ péng you ma?) Who is this? Is it your girlfriend?
- **B**: 不是，她是我姐姐。 (Bù shì, tā shì wǒ jiě jie.) No, she is my older sister.
  - ✓ 不是，她是我姐姐。 No, she is my older sister.
  - ✗ 这也是你姐姐吗？ (Point at another photo) Is this also your older sister? (from d32.3)
- **A**: 你有你女朋友的照片吗？ (Nǐ yǒu nǐ nǚ péng you de zhào piàn ma?) Do you have your girlfriend’s pictures?
  - ✓ 你有你女朋友的照片吗？ Do you have your girlfriend’s pictures?
  - ✗ 不是，她是我姐姐。 No, she is my older sister. (from d12.2)
- **B**: 有一张。……这是我，这是我女朋友。 (Yǒu yī zhāng.…… zhè shì wǒ, zhè shì wǒ nǚ péng you.) I have one…… This is me; this is my girlfriend.
  - ✓ 有一张。……这是我，这是我女朋友。 I have one…… This is me; this is my girlfriend.
  - ✗ 你有你女朋友的照片吗？ Do you have your girlfriend’s pictures? (from d12.3)
- **A**: 这个呢？ (Zhè gè ne?) What about this one?
  - ✓ 这个呢？ What about this one?
  - ✗ 在那儿！那儿有一辆日本车，那是我的车。 It’s over there! There is a Japanese car over there. That is my car. (from d19.4)

### Dialogue 13 (episode 02, up to HSK 4)

- **A**: 这是谁的照片？是你女朋友的吗？ (Zhè shì shéi de zhào piàn? Shì nǐ nǚ péng you de ma?) Whose picture is this? Is it your girlfriend’s?
- **B**: 不是，这是王先生的女朋友。 (Bù shì, zhè shì wáng xiān sheng de nǚ péng you.) No, this is Mr.
  - ✓ 不是，这是王先生的女朋友。 No, this is Mr.
  - ✗ 你有你女朋友的照片吗？ Do you have your girlfriend’s pictures? (from d12.3)
- **A**: 王先生？王先生是谁？ (Wáng xiān sheng? Wáng xiān sheng shì shéi?) Mr. Wang? Who is Mr. Wang?
  - ✓ 王先生？王先生是谁？ Mr. Wang? Who is Mr. Wang?
  - ✗ 不是，这是王先生的女朋友。 No, this is Mr. (from d13.2)
- **B**: 他是我哥哥的老师，他女朋友也是我哥哥的老师。 (Tā shì wǒ gē ge de lǎo shī, tā nǚ péng you yě shì wǒ gē ge de lǎo shī.) He is my older brother’s teacher. His girlfriend is also my older brother’s teacher.
  - ✓ 他是我哥哥的老师，他女朋友也是我哥哥的老师。 He is my older brother’s teacher. His girlfriend is also my older brother’s teacher.
  - ✗ 好。是谁？ OK! Who is it? (from d57.4)

### Dialogue 14 (episode 03, up to HSK 3)

- **A**: 这是谁的车？是你的吗？ (Zhè shì shéi de chē? Shì nǐ de ma?) Whose car is this? Is it yours?
- **B**: 不是，那是我爸爸的车，我没有车。 (Bù shì, nà shì wǒ bà ba de chē, wǒ méi yǒu chē.) No, that is my father’s car. I don’t have a car.
  - ✓ 不是，那是我爸爸的车，我没有车。 No, that is my father’s car. I don’t have a car.
  - ✗ 是吗？你的中文老师姓什么？ Is that so? What is your Chinese teacher’s last name? (from d15.7)
- **A**: 你爸爸的车是美国车吗？ (Nǐ bà ba de chē shì měi guó chē ma?) Is your father’s car an American car?
  - ✓ 你爸爸的车是美国车吗？ Is your father’s car an American car?
  - ✗ 不是，那是我爸爸的车，我没有车。 No, that is my father’s car. I don’t have a car. (from d14.2)
- **B**: 是，我妈妈的车也是美国车。你爸妈有车吗？ (Shì, wǒ mā ma de chē yě shì měi guó chē. Nǐ bà mā yǒu chē ma?) Yes. My mother’s car is also an American car. Do your parents have cars?
  - ✓ 是，我妈妈的车也是美国车。你爸妈有车吗？ Yes. My mother’s car is also an American car. Do your parents have cars?
  - ✗ 你爸爸的车是美国车吗？ Is your father’s car an American car? (from d14.3)

### Dialogue 15 (episode 03, up to HSK 99)

- **A**: 你是学生吗？ (Nǐ shì xué sheng ma?) Are you a student?
- **B**: 是，我是学生，你也是学生吗？ (Shì, wǒ shì xué sheng, nǐ yě shì xué sheng ma?) Yes, I am a student. Are you also a student?
  - ✓ 是，我是学生，你也是学生吗？ Yes, I am a student. Are you also a student?
  - ✗ 是，你也是中国学生吗？ Yes. Are you also a Chinese student? (from d30.2)
- **A**: 不是，我是老师。我姓王。 (Bù shì, wǒ shì lǎo shī. Wǒ xìng wáng.) No. I am a teacher. My last name is
  - ✓ 不是，我是老师。我姓王。 No. I am a teacher. My last name is
  - ✗ 是，我是学生，你也是学生吗？ Yes, I am a student. Are you also a student? (from d15.2)
- **B**: 王老师，你好。 (Wáng lǎo shī, nǐ hǎo.) Hello,
  - ✓ 王老师，你好。 Hello,
  - ✗ 不是，我是老师。我姓王。 No. I am a teacher. My last name is (from d15.3)
- **A**: 你好。你学什么？ (Nǐ hǎo. Nǐ xué shén me?) Hello. What do you study?
  - ✓ 你好。你学什么？ Hello. What do you study?
  - ✗ 王老师，你好。 Hello, (from d15.4)
- **B**: 我学中文。 (Wǒ xué zhōng wén.) I study
  - ✓ 我学中文。 I study
  - ✗ 我也学中文。你的中文老师姓什么？ I study Chinese, too. What is your Chinese teacher’s last name? (from d41.5)
- **A**: 是吗？你的中文老师姓什么？ (Shì ma? Nǐ de zhōng wén lǎo shī xìng shén me?) Is that so? What is your Chinese teacher’s last name?
  - ✓ 是吗？你的中文老师姓什么？ Is that so? What is your Chinese teacher’s last name?
  - ✗ 我学中文。 I study (from d15.6)

### Dialogue 16 (episode 03, up to HSK 3)

- **A**: 你家有几辆车？ (Nǐ jiā yǒu jǐ liàng chē?) How many cars does your family have?
- **B**: 两辆，我爸爸有一辆，我也有一辆。 (Liǎng liàng, wǒ bà ba yǒu yī liàng, wǒ yě yǒu yī liàng.) Two. My father has one; I have one.
  - ✓ 两辆，我爸爸有一辆，我也有一辆。 Two. My father has one; I have one.
  - ✗ 是吗？你有几个哥哥？ Is that so? How many older brothers do you have? (from d17.5)
- **A**: 你妈妈没有车吗？ (Nǐ mā ma méi yǒu chē ma?) Does your mother not have a car?
  - ✓ 你妈妈没有车吗？ Does your mother not have a car?
  - ✗ 两辆，我爸爸有一辆，我也有一辆。 Two. My father has one; I have one. (from d16.2)
- **B**: 没有，我弟弟也没有车。 (Méi yǒu, wǒ dì di yě méi yǒu chē.) No. My younger brother does not have a car, either.
  - ✓ 没有，我弟弟也没有车。 No. My younger brother does not have a car, either.
  - ✗ 你妈妈没有车吗？ Does your mother not have a car? (from d16.3)
- **A**: 你的车是哪国车？ (Nǐ de chē shì nǎ guó chē?) What kind (country of origin) of car your car?
  - ✓ 你的车是哪国车？ What kind (country of origin) of car your car?
  - ✗ 没有，我弟弟也没有车。 No. My younger brother does not have a car, either. (from d16.4)
- **B**: 我的车是日本车，我爸爸的是美国车。 (Wǒ de chē shì rì běn chē, wǒ bà ba de shì měi guó chē.) My car is a Japanese car. My father’s is an American car.
  - ✓ 我的车是日本车，我爸爸的是美国车。 My car is a Japanese car. My father’s is an American car.
  - ✗ 你的车是哪国车？ What kind (country of origin) of car your car? (from d16.5)

### Dialogue 17 (episode 03, up to HSK 3)

- **A**: 这个人是谁？ (Zhè gè rén shì shéi?) Who is this person?
- **B**: 是我哥哥。 (Shì wǒ gē ge.) It’s my older brother.
  - ✓ 是我哥哥。 It’s my older brother.
  - ✓ 那是我爸爸。 That is my father. (from d33.2, then carries on there)
  - ✗ 这是我男朋友的照片。 This is a picture of my boyfriend. (from d31.2)

### Dialogue 19 (episode 03, up to HSK 2)

- **A**: 这儿有两辆车，哪辆是你的？ (Zhèr yǒu liǎng liàng chē, nǎ liàng shì nǐ de?) There are two cars here. Which one is yours?
- **B**: 那两辆车都不是我的，我的车是日本车。 (Nà liǎng liàng chē dōu bù shì wǒ de, wǒ de chē shì rì běn chē.) Neither of those two cars are mine. My car is a
  - ✓ 那两辆车都不是我的，我的车是日本车。 Neither of those two cars are mine. My car is a
  - ✗ 你的车是哪国车？ What kind (country of origin) of car your car? (from d16.5)
- **A**: 那你的车在哪儿？ (Nà nǐ de chē zài nǎr?) Then where is your car?
  - ✓ 那你的车在哪儿？ Then where is your car?
  - ✗ 那两辆车都不是我的，我的车是日本车。 Neither of those two cars are mine. My car is a (from d19.2)
- **B**: 在那儿！那儿有一辆日本车，那是我的车。 (Zài nàr! Nàr yǒu yī liàng rì běn chē, nà shì wǒ de chē.) It’s over there! There is a Japanese car over there. That is my car.
  - ✓ 在那儿！那儿有一辆日本车，那是我的车。 It’s over there! There is a Japanese car over there. That is my car.
  - ✗ 那你的车在哪儿？ Then where is your car? (from d19.3)

### Dialogue 21 (episode 03, up to HSK 3)

- **A**: 你家在哪儿？ (Nǐ jiā zài nǎr?) Where is your home?
- **B**: 我家有六个人，我爸妈在外国，我哥哥、姐姐都在北京。 (Wǒ jiā yǒu liù gè rén, wǒ bà mā zài wài guó, wǒ gē ge, jiě jie dōu zài běi jīng.) My family has six people. My parents are abroad (in a foreign country). My older brothers and older sister are in
  - ✓ 我家有六个人，我爸妈在外国，我哥哥、姐姐都在北京。 My family has six people. My parents are abroad (in a foreign country). My older brothers and older sister are in
  - ✗ 那你的车在哪儿？ Then where is your car? (from d19.3)
- **A**: 你哥哥、姐姐做什么工作？ (Nǐ gē ge, jiě jie zuò shén me gōng zuò?) What do your older brothers and older sister do?
  - ✓ 你哥哥、姐姐做什么工作？ What do your older brothers and older sister do?
  - ✗ 我的两个哥哥都是北京大学的学生；我姐姐是那儿的老师。 Both of my older brothers are students at Beijing University. My older sister is a teacher there. (from d21.4)
- **B**: 我的两个哥哥都是北京大学的学生；我姐姐是那儿的老师。 (Wǒ de liǎng gè gē ge dōu shì běi jīng dà xué de xué sheng; wǒ jiě jie shì nàr de lǎo shī.) Both of my older brothers are students at Beijing University. My older sister is a teacher there.
  - ✓ 我的两个哥哥都是北京大学的学生；我姐姐是那儿的老师。 Both of my older brothers are students at Beijing University. My older sister is a teacher there.
  - ✗ 你哥哥、姐姐做什么工作？ What do your older brothers and older sister do? (from d21.3)

### Dialogue 22 (episode 04, up to HSK 99)

_A secretary greets someone on the job for the first day._

- **Secretary**: 你好！请问你贵姓？ (Nǐ hǎo! Qǐng wèn nǐ guì xìng?) Hello! What is your last name?
- **New employee**: 我姓王。 (Wǒ xìng wáng.) My last name is
  - ✓ 我姓王。 My last name is
  - ✗ 请叫我贵一，好吗？你贵姓？ Please call me Guiyi, OK? What is your honorable last name? (from d9.4)

### Dialogue 24 (episode 04, up to HSK 99)

_A new student approaches the registration desk. A man is sitting behind the desk._

- **Man**: 你好！你姓什么？ (Nǐ hǎo! Nǐ xìng shén me?) Hello. What is your last name?
- **Student**: 我姓王。 (Wǒ xìng wáng.) My last name is
  - ✓ 我姓王。 My last name is
  - ✗ 是吗？你的中文老师姓什么？ Is that so? What is your Chinese teacher’s last name? (from d15.7)

### Dialogue 29 (episode 05, up to HSK 1)

_A man and a woman are about to enter the Chinese embassy to attend a reception._

- **A**: 先生，请问你是中国人吗？ (Xiān sheng, qǐng wèn nǐ shì zhōng guó rén ma?) Sir, may I please ask if you are Chinese?
- **B**: 我不是中国人。 (Wǒ bù shì zhōng guó rén.) I am not
  - ✓ 我不是中国人。 I am not
  - ✗ 你男朋友是外国人吗？ Is your boyfriend a foreigner? (from d20.5)
- **A**: 你的朋友呢? (Nǐ de péng you ne?) What about your friend?
  - ✓ 你的朋友呢? What about your friend?
  - ✗ 我不是中国人。 I am not (from d29.2)
- **B**: 她也不是中国人。 (Tā yě bù shì zhōng guó rén.) She is not Chinese, either. (A checks B's invitation.)
  - ✓ 她也不是中国人。 She is not Chinese, either. (A checks B's invitation.)
  - ✗ 你的朋友呢? What about your friend? (from d29.3)

### Dialogue 30 (episode 05, up to HSK 1)

- **A**: 请问你是中国学生吗？ (Qǐng wèn nǐ shì zhōng guó xué sheng ma?) Excuse me, are you a Chinese student?
- **B**: 是，你也是中国学生吗？ (Shì, nǐ yě shì zhōng guó xué sheng ma?) Yes. Are you also a Chinese student?
  - ✓ 是，你也是中国学生吗？ Yes. Are you also a Chinese student?
  - ✗ 是，我是学生，你也是学生吗？ Yes, I am a student. Are you also a student? (from d15.2)

### Dialogue 31 (episode 06, up to HSK 3)

- **王**: 这是什么？ (Zhè shì shén me?) What is this?
- **李**: 这是我男朋友的照片。 (Zhè shì wǒ nán péng you de zhào piàn.) This is a picture of my boyfriend.
  - ✓ 这是我男朋友的照片。 This is a picture of my boyfriend.
  - ✓ 这是我家人的照片。 This is a picture of my family. (from d36.2, then carries on there)
  - ✗ 这是什么字？ (Pointing at the character B knows) What character is this? (from d65.7)
- **王**: 你男朋友是美国人吗？ (Nǐ nán péng you shì měi guó rén ma?) Is your boyfriend an American?
  - ✓ 你男朋友是美国人吗？ Is your boyfriend an American?
  - ✗ 有，这儿有七、八张他的照片。……这是我男朋友，这几个是他家人。 Yes. There are seven or eight pictures of his here. …… This is my boyfriend; these few are his family (members). (from d20.4)
- **李**: 他爸爸是美国人，他妈妈是中国人。 (Tā bà ba shì měi guó rén, tā mā ma shì zhōng guó rén.) His father is an American; his mother is
  - ✓ 他爸爸是美国人，他妈妈是中国人。 His father is an American; his mother is
  - ✗ 你男朋友是美国人吗？ Is your boyfriend an American? (from d31.3)
- **王**: 他有中文名字吗？ (Tā yǒu zhōng wén míng zi ma?) Does he have a Chinese name?
  - ✓ 他有中文名字吗？ Does he have a Chinese name?
  - ✗ 我不是中国人。 I am not (from d29.2)

### Dialogue 32 (episode 06, up to HSK 1)

_Wang is showing a couple of photographs to Li._

- **李**: 这是谁？ (Zhè shì shéi?) Who is this?
- **王**: 这是我姐姐。 (Zhè shì wǒ jiě jie.) This is my older sister.
  - ✓ 这是我姐姐。 This is my older sister.
  - ✗ 这是我男朋友的照片。 This is a picture of my boyfriend. (from d31.2)
- **李**: 这也是你姐姐吗？ (Zhè yě shì nǐ jiě jie ma?) (Point at another photo) Is this also your older sister?
  - ✓ 这也是你姐姐吗？ (Point at another photo) Is this also your older sister?
  - ✗ 这是我姐姐。 This is my older sister. (from d32.2)
- **王**: 不是，那是我姐姐的女儿。 (Bù shì, nà shì wǒ jiě jie de nǚ ér.) No, that is my older sister’s daughter.
  - ✓ 不是，那是我姐姐的女儿。 No, that is my older sister’s daughter.
  - ✗ 这也是你姐姐吗？ (Point at another photo) Is this also your older sister? (from d32.3)
- **李**: 你姐姐有儿子吗？ (Nǐ jiě jie yǒu ér zi ma?) Does your older sister have sons?
  - ✓ 你姐姐有儿子吗？ Does your older sister have sons?
  - ✗ 不是，那是我姐姐的女儿。 No, that is my older sister’s daughter. (from d32.4)

### Dialogue 33 (episode 06, up to HSK 3)

_Wang is looking at Li’s family picture._

- **王**: 这个人是谁？ (Zhè gè rén shì shéi?) Who is this man?
- **李**: 那是我爸爸。 (Nà shì wǒ bà ba.) That is my father.
  - ✓ 那是我爸爸。 That is my father.
  - ✓ 是我哥哥。 It’s my older brother. (from d17.2, then carries on there)
  - ✗ 这是我男朋友的照片。 This is a picture of my boyfriend. (from d31.2)
- **王**: 这个呢？ (Zhè gè ne?) How about this one?
  - ✓ 这个呢？ How about this one?
  - ✗ 不是，那是我爸爸的车，我没有车。 No, that is my father’s car. I don’t have a car. (from d14.2)
- **李**: 那是我哥哥。 (Nà shì wǒ gē ge.) That is my older brother.
  - ✓ 那是我哥哥。 That is my older brother.
  - ✗ 这个呢？ What about this one? (from d12.5)
- **王**: 这是你妈妈吗？ (Zhè shì nǐ mā ma ma?) Is this your mother?
  - ✓ 这是你妈妈吗？ Is this your mother?
  - ✗ 那是我哥哥。 That is my older brother. (from d33.4)
- **李**: 不是，那是我爸爸的姐姐。 (Bù shì, nà shì wǒ bà ba de jiě jie.) No, that is my father’s older sister.
  - ✓ 不是，那是我爸爸的姐姐。 No, that is my father’s older sister.
  - ✗ 这是你妈妈吗？ Is this your mother? (from d33.5)

### Dialogue 34 (episode 06, up to HSK 4)

_Wang is looking at a picture in a frame on Li’s desk._

- **王**: 这五个人是谁？ (Zhè wǔ gè rén shì shéi?) Who are these five people?
- **李**: 这是我爸爸，这是我妈妈，这三个是我哥哥。 (Zhè shì wǒ bà ba, zhè shì wǒ mā ma, zhè sān gè shì wǒ gē ge.) This is my father; this is my mother; these three are my older brothers.
  - ✓ 这是我爸爸，这是我妈妈，这三个是我哥哥。 This is my father; this is my mother; these three are my older brothers.
  - ✗ 这是我男朋友的照片。 This is a picture of my boyfriend. (from d31.2)
- **王**: 这是你大哥吗？ (Zhè shì nǐ dà gē ma?) Is this your eldest brother?
  - ✓ 这是你大哥吗？ Is this your eldest brother?
  - ✗ 这是我爸爸，这是我妈妈，这三个是我哥哥。 This is my father; this is my mother; these three are my older brothers. (from d34.2)
- **李**: 不是，那是我二哥。 (Bù shì, nà shì wǒ èr gē.) No, that is my second eldest brother.
  - ✓ 不是，那是我二哥。 No, that is my second eldest brother.
  - ✗ 这也是你姐姐吗？ (Point at another photo) Is this also your older sister? (from d32.3)

### Dialogue 36 (episode 07, up to HSK 3)

- **王**: 这是什么？ (Zhè shì shén me?) What is this?
- **李**: 这是我家人的照片。 (Zhè shì wǒ jiā rén de zhào piàn.) This is a picture of my family.
  - ✓ 这是我家人的照片。 This is a picture of my family.
  - ✓ 这是我男朋友的照片。 This is a picture of my boyfriend. (from d31.2, then carries on there)
  - ✗ 这是什么字？ (Pointing at the character B knows) What character is this? (from d65.7)
- **王**: 一、二、三、四、五、六，你家有六个人吗？ (Yī, èr, sān, sì, wǔ, liù, nǐ jiā yǒu liù gè rén ma?) (Counting) one, two, three, four, five, six. Does your family have six people?
  - ✓ 一、二、三、四、五、六，你家有六个人吗？ (Counting) one, two, three, four, five, six. Does your family have six people?
  - ✗ 有，这儿有七、八张他的照片。……这是我男朋友，这几个是他家人。 Yes. There are seven or eight pictures of his here. …… This is my boyfriend; these few are his family (members). (from d20.4)
- **李**: 我家有五个人。这个是我姐姐的男朋友。 (Wǒ jiā yǒu wǔ gè rén. Zhè gè shì wǒ jiě jie de nán péng you.) There are five people in my family. (Pointing at a man in the picture) This one is my older sister’s boyfriend.
  - ✓ 我家有五个人。这个是我姐姐的男朋友。 There are five people in my family. (Pointing at a man in the picture) This one is my older sister’s boyfriend.
  - ✗ 一、二、三、四、五、六，你家有六个人吗？ (Counting) one, two, three, four, five, six. Does your family have six people? (from d36.3)

### Dialogue 37 (episode 07, up to HSK 4)

- **李**: 你有姐妹吗？ (Nǐ yǒu jiě mèi ma?) Do you have sisters?
- **王**: 有，我有两个姐姐、一个妹妹。你呢？ (Yǒu, wǒ yǒu liǎng gè jiě jie, yī gè mèi mei. Nǐ ne?) Yes, I have two older sisters and one younger sister. How about you?
  - ✓ 有，我有两个姐姐、一个妹妹。你呢？ Yes, I have two older sisters and one younger sister. How about you?
  - ✗ 我有一个姐姐，没有妹妹。你有哥哥、弟弟吗？ I have one older sister; I don’t have younger sisters. Do you have brothers? (from d8.3)
- **李**: 我也有两个姐姐，没有妹妹。 (Wǒ yě yǒu liǎng gè jiě jie, méi yǒu mèi mei.) I also have two older sisters; I don’t have any younger sisters.
  - ✓ 我也有两个姐姐，没有妹妹。 I also have two older sisters; I don’t have any younger sisters.
  - ✗ 有，我有两个姐姐、一个妹妹。你呢？ Yes, I have two older sisters and one younger sister. How about you? (from d37.2)
- **王**: 你有你姐姐的照片吗？ (Nǐ yǒu nǐ jiě jie de zhào piàn ma?) Do you have your sisters’ pictures?
  - ✓ 你有你姐姐的照片吗？ Do you have your sisters’ pictures?
  - ✗ 我也有两个姐姐，没有妹妹。 I also have two older sisters; I don’t have any younger sisters. (from d37.3)
- **李**: 有。…. 这是我大姐，这是我二姐。 (Yǒu.…. Zhè shì wǒ dà jiě, zhè shì wǒ èr jiě.) Yes. (Taking out a couple of pictures) This is my eldest sister, and this is my second eldest sister.
  - ✓ 有。…. 这是我大姐，这是我二姐。 Yes. (Taking out a couple of pictures) This is my eldest sister, and this is my second eldest sister.
  - ✗ 你有你姐姐的照片吗？ Do you have your sisters’ pictures? (from d37.4)
- **王**: 什么？这是你大姐？她是我哥哥的女朋友。 (Shén me? Zhè shì nǐ dà jiě? Tā shì wǒ gē ge de nǚ péng you.) What? This is your eldest sister? She is my older brother’s girlfriend.
  - ✓ 什么？这是你大姐？她是我哥哥的女朋友。 What? This is your eldest sister? She is my older brother’s girlfriend.
  - ✗ 有。…. 这是我大姐，这是我二姐。 Yes. (Taking out a couple of pictures) This is my eldest sister, and this is my second eldest sister. (from d37.5)

### Dialogue 38 (episode 07, up to HSK 2)

- **王**: 你爸妈做什么工作？ (Nǐ bà mā zuò shén me gōng zuò?) What (line of) work do your parents do?
- **李**: 我爸爸是医生，我妈妈没有工作。 (Wǒ bà ba shì yī shēng, wǒ mā ma méi yǒu gōng zuò.) My father is a doctor. My mother does not have a job.
  - ✓ 我爸爸是医生，我妈妈没有工作。 My father is a doctor. My mother does not have a job.
  - ✓ 我爸爸是医生，妈妈没有工作。  (author's alternative)
  - ✗ 你哥哥、姐姐做什么工作？ What do your older brothers and older sister do? (from d21.3)
- **王**: 是吗？我爸爸也是医生。 (Shì ma? Wǒ bà ba yě shì yī shēng.) Is that so? My father is also a doctor.
  - ✓ 是吗？我爸爸也是医生。 Is that so? My father is also a doctor.
  - ✗ 我爸爸是医生，我妈妈没有工作。 My father is a doctor. My mother does not have a job. (from d38.2)
- **李**: 你妈妈有工作吗？ (Nǐ mā ma yǒu gōng zuò ma?) Does your mother have a job?
  - ✓ 你妈妈有工作吗？ Does your mother have a job?
  - ✗ 是吗？我爸爸也是医生。 Is that so? My father is also a doctor. (from d38.3)
- **王**: 有。她是北京大学的英文老师。 (Yǒu. Tā shì běi jīng dà xué de yīng wén lǎo shī.) Yes, she does. She is an English teacher at Beijing University.
  - ✓ 有。她是北京大学的英文老师。 Yes, she does. She is an English teacher at Beijing University.
  - ✗ 你妈妈有工作吗？ Does your mother have a job? (from d38.4)

### Dialogue 39 (episode 07, up to HSK 1)

- **王**: 请问，你是这个大学的老师吗？ (Qǐng wèn, nǐ shì zhè gè dà xué de lǎo shī ma?) Excuse me. Are you a teacher of this university?
- **李**: 不是，我是学生。你呢？ (Bù shì, wǒ shì xué sheng. Nǐ ne?) No, I am a student. How about you?
  - ✓ 不是，我是学生。你呢？ No, I am a student. How about you?
  - ✗ 是吗？你的中文老师姓什么？ Is that so? What is your Chinese teacher’s last name? (from d15.7)
- **王**: 我也是学生。你叫什么名字？ (Wǒ yě shì xué sheng. Nǐ jiào shén me míng zi?) I am also a student. What is your name?
  - ✓ 我也是学生。你叫什么名字？ I am also a student. What is your name?
  - ✗ 我不是老师，是学生。你呢？ I am not a teacher; I am a student. How about you? (from d27.4)

### Dialogue 40 (episode 07, up to HSK 4)

- **王**: 你有哥哥、弟弟吗？ (Nǐ yǒu gē ge, dì di ma?) Do you have brothers?
- **李**: 我有两个哥哥，没有弟弟。 (Wǒ yǒu liǎng gè gē ge, méi yǒu dì di.) I have two older brothers, and no younger brothers.
  - ✓ 我有两个哥哥，没有弟弟。 I have two older brothers, and no younger brothers.
  - ✗ 我有一个姐姐，没有妹妹。你有哥哥、弟弟吗？ I have one older sister; I don’t have younger sisters. Do you have brothers? (from d8.3)
- **王**: 你哥哥都是大学生吗？ (Nǐ gē ge dōu shì dà xué shēng ma?) Are your brothers both college students?
  - ✓ 你哥哥都是大学生吗？ Are your brothers both college students?
  - ✗ 我有两个哥哥，没有弟弟。 I have two older brothers, and no younger brothers. (from d40.2)
- **李**: 我哥哥都是律师。 (Wǒ gē ge dōu shì lǜ shī.) My brothers are both lawyers.
  - ✓ 我哥哥都是律师。 My brothers are both lawyers.
  - ✗ 你哥哥都是大学生吗？ Are your brothers both college students? (from d40.3)
- **王**: 是吗？我有两个弟弟，他们也都是律师。 (Shì ma? Wǒ yǒu liǎng gè dì di, tā men yě dōu shì lǜ shī.) Is that so? I have two younger brothers. Both of them are also lawyers.
  - ✓ 是吗？我有两个弟弟，他们也都是律师。 Is that so? I have two younger brothers. Both of them are also lawyers.
  - ✗ 我哥哥都是律师。 My brothers are both lawyers. (from d40.4)

### Dialogue 41 (episode 07, up to HSK 99)

_Two college students are having a conversation._

- **王**: 你是哪个大学的学生？ (Nǐ shì nǎ gè dà xué de xué sheng?) What school do you go to?
- **李**: 我是德州大学的学生。 (Wǒ shì dé zhōu dà xué de xué sheng.) I go to the University of Texas (UT).
  - ✓ 我是德州大学的学生。 I go to the University of Texas (UT).
  - ✗ 我的两个哥哥都是北京大学的学生；我姐姐是那儿的老师。 Both of my older brothers are students at Beijing University. My older sister is a teacher there. (from d21.4)
- **王**: 是吗？我也是德州大学的学生。你学什么？ (Shì ma? Wǒ yě shì dé zhōu dà xué de xué sheng. Nǐ xué shén me?) Is that so? I also go to UT. What do you study?
  - ✓ 是吗？我也是德州大学的学生。你学什么？ Is that so? I also go to UT. What do you study?
  - ✗ 我是德州大学的学生。 I go to the University of Texas (UT). (from d41.2)
- **李**: 我学中文。你呢？ (Wǒ xué zhōng wén. Nǐ ne?) I study Chinese. How about you?
  - ✓ 我学中文。你呢？ I study Chinese. How about you?
  - ✗ 是，我是学生，你也是学生吗？ Yes, I am a student. Are you also a student? (from d15.2)
- **王**: 我也学中文。你的中文老师姓什么？ (Wǒ yě xué zhōng wén. Nǐ de zhōng wén lǎo shī xìng shén me?) I study Chinese, too. What is your Chinese teacher’s last name?
  - ✓ 我也学中文。你的中文老师姓什么？ I study Chinese, too. What is your Chinese teacher’s last name?
  - ✗ 我学中文。你呢？ I study Chinese. How about you? (from d41.4)

### Dialogue 43 (episode 08, up to HSK 4)

- **张**: 你认识不认识王小姐？ (Nǐ rèn shi bù rèn shi wáng xiǎo jie?) Do you know Miss Wang?
- **谢**: 王小姐？哪个王小姐？ (Wáng xiǎo jie? Nǎ gè wáng xiǎo jie?) Miss Wang? Which Miss Wang?
  - ✓ 王小姐？哪个王小姐？ Miss Wang? Which Miss Wang?
  - ✗ 都是他的老同学，我想你不认识他们。 All were his old classmates. I don’t think you know them. (from d55.6)

### Dialogue 45 (episode 08, up to HSK 3)

- **李先生**: 这几个人是谁？ (Zhè jǐ gè rén shì shéi?) (Pointing at some people in a photo) Who are these people?
- **王太太**: 这是我女儿，这两个是我儿子。 (Zhè shì wǒ nǚ ér, zhè liǎng gè shì wǒ ér zi.) This is my daughter, and these two are my sons.
  - ✓ 这是我女儿，这两个是我儿子。 This is my daughter, and these two are my sons.
  - ✗ 是吗？这一课有几个生词？ Is that so? How many vocabulary words are there in this lesson? (from d66.3)
- **李先生**: 你有三个孩子吗？ (Nǐ yǒu sān gè hái zi ma?) Do you have three children?
  - ✓ 你有三个孩子吗？ Do you have three children?
  - ✗ 这是我女儿，这两个是我儿子。 This is my daughter, and these two are my sons. (from d45.2)

### Dialogue 46 (episode 09, up to HSK 1)

- **女**: 你爱不爱我？ (Nǐ ài bù ài wǒ?) Do you love me?
- **男**: 爱！ (Ài!) Yes,
  - ✓ 爱！ Yes,
  - ✗ 我爸爸很忙，我妈妈不忙。你爸妈忙吗？ My father is busy; my mother is not. Are your parents busy? (from d3.4)

### Dialogue 47 (episode 09, up to HSK 2)

- **李**: 高先生，我姐姐在那儿。你们认识不认识？ (Gāo xiān sheng, wǒ jiě jie zài nàr. Nǐ men rèn shi bù rèn shi?) Mr. Gao, my older sister is over there. Do you (plural) know each other?
- **高**: 我认识她，可是她不认识我。 (Wǒ rèn shi tā, kě shì tā bù rèn shi wǒ.) I know her, but she does not know me.
  - ✓ 我认识她，可是她不认识我。 I know her, but she does not know me.
  - ✗ 不是，她是我姐姐。 No, she is my older sister. (from d12.2)

### Dialogue 49 (episode 10, up to HSK 1)

- **李**: 小高，你去哪儿？ (Xiǎo gāo, nǐ qù nǎr?) Where are you going, Little Gao?
- **高**: 我去我女朋友家。 (Wǒ qù wǒ nǚ péng you jiā.) I am going to my girlfriend’s house.
  - ✓ 我去我女朋友家。 I am going to my girlfriend’s house.
  - ✗ 那你的车在哪儿？ Then where is your car? (from d19.3)
- **李**: 你去那儿做什么？ (Nǐ qù nàr zuò shén me?) Why are you going there?
  - ✓ 你去那儿做什么？ Why are you going there?
  - ✗ 我去我女朋友家。 I am going to my girlfriend’s house. (from d49.2)
- **高**: 我去那儿吃晚饭。今天她请几个朋友吃饭。 (Wǒ qù nàr chī wǎn fàn. Jīn tiān tā qǐng jǐ gè péng you chī fàn.) I am going there to have dinner. She has invited a few friends for dinner today.
  - ✓ 我去那儿吃晚饭。今天她请几个朋友吃饭。 I am going there to have dinner. She has invited a few friends for dinner today.
  - ✗ 你去那儿做什么？ Why are you going there? (from d49.3)

### Dialogue 50 (episode 10, up to HSK 2)

- **男**: 你喜欢看外国电影还是中国电影？ (Nǐ xǐ huan kàn wài guó diàn yǐng hái shi zhōng guó diàn yǐng?) Do you like (to see) foreign movies or Chinese movies?
- **女**: 我都喜欢，可是我很忙，所以不常看电影。 (Wǒ dōu xǐ huan, kě shì wǒ hěn máng, suǒ yǐ bù cháng kàn diàn yǐng.) I like both, but I am busy, so I don’t often see movies.
  - ✓ 我都喜欢，可是我很忙，所以不常看电影。 I like both, but I am busy, so I don’t often see movies.
  - ✗ 是中国电影还是外国电影？ Are they Chinese movies or foreign movies? (from d64.2)
- **男**: 这个周末有一个外国电影，这个电影很好看，我们去看，怎么样？我请客。 (Zhè gè zhōu mò yǒu yī gè wài guó diàn yǐng, zhè gè diàn yǐng hěn hǎo kàn, wǒ men qù kàn, zěn me yàng? Wǒ qǐng kè.) There is a foreign movie this weekend. This movie is good. How about if we go see it? It will be my treat.
  - ✓ 这个周末有一个外国电影，这个电影很好看，我们去看，怎么样？我请客。 There is a foreign movie this weekend. This movie is good. How about if we go see it? It will be my treat.
  - ✗ 我都喜欢，可是我很忙，所以不常看电影。 I like both, but I am busy, so I don’t often see movies. (from d50.2)
- **女**: 是吗？谢谢。星期六还是星期天？是哪国电影？ (Shì ma? Xiè xie. Xīng qī liù hái shi xīng qī tiān? Shì nǎ guó diàn yǐng?) Is that so? Thank you. Saturday or Sunday? What country movie is it?
  - ✓ 是吗？谢谢。星期六还是星期天？是哪国电影？ Is that so? Thank you. Saturday or Sunday? What country movie is it?
  - ✗ 这个周末有一个外国电影，这个电影很好看，我们去看，怎么样？我请客。 There is a foreign movie this weekend. This movie is good. How about if we go see it? It will be my treat. (from d50.3)
- **男**: 星期六晚上。是一个日本电影。 (Xīng qī liù wǎn shang. Shì yī gè rì běn diàn yǐng.) Saturday evening. It’s a
  - ✓ 星期六晚上。是一个日本电影。 Saturday evening. It’s a
  - ✗ 是吗？谢谢。星期六还是星期天？是哪国电影？ Is that so? Thank you. Saturday or Sunday? What country movie is it? (from d50.4)

### Dialogue 51 (episode 10, up to HSK 2)

- **王**: 你周末常做什么？ (Nǐ zhōu mò cháng zuò shén me?) What do you often do on weekends?
- **谢**: 我有的时候工作，有的时候看书。 (Wǒ yǒu de shí hou gōng zuò, yǒu de shí hou kàn shū.) Sometimes I work; and sometimes
  - ✓ 我有的时候工作，有的时候看书。 Sometimes I work; and sometimes
  - ✓ 有的时候工作，有的时候看书。  (author's alternative)
  - ✗ 你哥哥、姐姐做什么工作？ What do your older brothers and older sister do? (from d21.3)

### Dialogue 57 (episode 15, up to HSK 99)

_Ring, Ring_

- **A**: 喂？ (Wèi?) Hello?
- **B**: 请问高大中在不在？ (Qǐng wèn gāo dà zhōng zài bù zài?) May I speak to Dazhong Gao?
  - ✓ 请问高大中在不在？ May I speak to Dazhong Gao?
  - ✗ 我很好。 I am fine. (from d2.2)
- **A**: 请等一下，我去看一下他在不在家……大中，电话。 (Qǐng děng yī xià, wǒ qù kàn yī xià tā zài bù zài jiā…… dà zhōng, diàn huà.) Please wait for a moment. I will go take a look (to see) if he is home …. Dazhong, phonecall.
  - ✓ 请等一下，我去看一下他在不在家……大中，电话。 Please wait for a moment. I will go take a look (to see) if he is home …. Dazhong, phonecall.
  - ✗ 请问高大中在不在？ May I speak to Dazhong Gao? (from d57.2)
- **C**: 好。是谁？ (Hǎo. Shì shéi?) OK! Who is it?
  - ✓ 好。是谁？ OK! Who is it?
  - ✗ 你们在这儿坐一下吧。我去一下洗手间。 Why don’t you sit here for a while. I will quickly run (go) to the bathroom. (from d54.11)

### Dialogue 61 (episode 17, up to HSK 1)

- **A**: 你这个星期有几个考试？ (Nǐ zhè gè xīng qī yǒu jǐ gè kǎo shì?) How many tests do you have this week?
- **B**: 有两个。我昨天考了一个，今天考了一个。 (Yǒu liǎng gè. Wǒ zuó tiān kǎo le yī gè, jīn tiān kǎo le yī gè.) I had two. I took one yesterday and I took one today.
  - ✓ 有两个。我昨天考了一个，今天考了一个。 I had two. I took one yesterday and I took one today.
  - ✗ 是吗？你有几个哥哥？ Is that so? How many older brothers do you have? (from d17.5)

### Dialogue 62 (episode 18, up to HSK 3)

- **A**: 那个人是谁？ (Nà gè rén shì shéi?) Who is that person?
- **B**: 哪个人？那里有两个人。 (Nǎ gè rén? Nà li yǒu liǎng gè rén.) Which person? There are two people over there. Male or female?
  - ✓ 哪个人？那里有两个人。 Which person? There are two people over there. Male or female?
  - ✗ 这八个人是谁？我认识他们吗？ Who were these eight people? Do I know them? (from d55.5)

### Dialogue 64 (episode 18, up to HSK 7)

- **A**: 今天晚上有两个电影；你想看哪个？ (Jīn tiān wǎn shang yǒu liǎng gè diàn yǐng; nǐ xiǎng kàn nǎ gè?) There are two movies this evening. Which one do you want to see?
- **B**: 是中国电影还是外国电影？ (Shì zhōng guó diàn yǐng hái shi wài guó diàn yǐng?) Are they Chinese movies or foreign movies?
  - ✓ 是中国电影还是外国电影？ Are they Chinese movies or foreign movies?
  - ✗ 你们想看哪个电影？ Which movie do you have in mind? (=Which movie do you want to see?) (from d56.15)
- **A**: 两个都是外国电影。一个是法文的；一个是日文的。 (Liǎng gè dōu shì wài guó diàn yǐng. Yī gè shì fǎ wén de; yī gè shì rì wén de.) Both are foreign movies. One is in French; one is in Japanese.
  - ✓ 两个都是外国电影。一个是法文的；一个是日文的。 Both are foreign movies. One is in French; one is in Japanese.
  - ✗ 是中国电影还是外国电影？ Are they Chinese movies or foreign movies? (from d64.2)

### Dialogue 65 (episode 18, up to HSK 1)

- **A**: 这三个字，你认识几个？ (Zhè sān gè zì, nǐ rèn shi jǐ gè?) Of these three characters, how many do you know?
- **B**: 我认识一个。 (Wǒ rèn shi yī gè.) I know one.
  - ✓ 我认识一个。 I know one.
  - ✗ 不对！这是“太”字。这三个字，你都不认识。 Wrong! This is character “t]ai.” You know none of these three characters. (from d65.9)
- **A**: 是吗？你认识哪一个？ (Shì ma? Nǐ rèn shi nǎ yī gè?) Is that so? Which one do you know?
  - ✓ 是吗？你认识哪一个？ Is that so? Which one do you know?
  - ✓ 是吗？你认识哪个？  (author's alternative)
  - ✗ 对！我认识一个高小姐。 That’s correct! I know a (from d58.4)
- **B**: 我认识这一个。 (Wǒ rèn shi zhè yī gè.) I know this one.
  - ✓ 我认识这一个。 I know this one.
  - ✓ 我认识这个。  (author's alternative)
  - ✗ 是吗？你认识哪一个？ Is that so? Which one do you know? (from d65.3)
- **A**: 这两个呢？ (Zhè liǎng gè ne?) What about these two?
  - ✓ 这两个呢？ What about these two?
  - ✗ 我认识这一个。 I know this one. (from d65.4)
- **B**: 这两个我都不认识。 (Zhè liǎng gè wǒ dōu bù rèn shi.) I know neither of them.
  - ✓ 这两个我都不认识。 I know neither of them.
  - ✓ 我都不认识。  (author's alternative)
  - ✗ 这两个呢？ What about these two? (from d65.5)
- **A**: 这是什么字？ (Zhè shì shén me zì?) (Pointing at the character B knows) What character is this?
  - ✓ 这是什么字？ (Pointing at the character B knows) What character is this?
  - ✗ 这两个我都不认识。 I know neither of them. (from d65.6)
- **B**: 是“大”字。 (Shì" dà" zì.) It is character “d]a.”
  - ✓ 是“大”字。 It is character “d]a.”
  - ✗ 这是什么字？ (Pointing at the character B knows) What character is this? (from d65.7)
- **A**: 不对！这是“太”字。这三个字，你都不认识。 (Bù duì! Zhè shì" tài" zì. Zhè sān gè zì, nǐ dōu bù rèn shi.) Wrong! This is character “t]ai.” You know none of these three characters.
  - ✓ 不对！这是“太”字。这三个字，你都不认识。 Wrong! This is character “t]ai.” You know none of these three characters.
  - ✗ 是“大”字。 It is character “d]a.” (from d65.8)

### Dialogue 66 (episode 18, up to HSK 7)

- **A**: 你觉得学语法难还是写汉字难？ (Nǐ jué de xué yǔ fǎ nán hái shi xiě hàn zì nán?) Do you think learning grammar is harder or writing Chinese characters is harder?
- **B**: 很难说。第八课的语法很容易，可是生词很多，有的很难。 (Hěn nán shuō. Dì bā kè de yǔ fǎ hěn róng yì, kě shì shēng cí hěn duō, yǒu de hěn nán.) Hard to say. Grammar in (=of) Lesson 8 is easy, but there are many vocabulary words. Some are hard.
  - ✓ 很难说。第八课的语法很容易，可是生词很多，有的很难。 Hard to say. Grammar in (=of) Lesson 8 is easy, but there are many vocabulary words. Some are hard.
  - ✗ 我学中文。你呢？ I study Chinese. How about you? (from d41.4)
- **A**: 是吗？这一课有几个生词？ (Shì ma? Zhè yī kè yǒu jǐ gè shēng cí?) Is that so? How many vocabulary words are there in this lesson?
  - ✓ 是吗？这一课有几个生词？ Is that so? How many vocabulary words are there in this lesson?
  - ✓ 是吗？这课有几个生词？  (author's alternative)
  - ✗ 我都喜欢，可是我很忙，所以不常看电影。 I like both, but I am busy, so I don’t often see movies. (from d50.2)

### Dialogue 70 (episode 20, up to HSK 5)

- **妈**: 小中，爸爸回家了没有？ (Xiǎo zhōng, bà ba huí jiā le méi yǒu?) Little Zhong, has your dad come home?
- **中**: 他已经回来了。 (Tā yǐ jīng huí lai le.) He has already come back.
  - ✓ 他已经回来了。 He has already come back.
  - ✗ 不是，那是我爸爸的车，我没有车。 No, that is my father’s car. I don’t have a car. (from d14.2)
- **妈**: 他在做什么？ (Tā zài zuò shén me?) What is he doing?
  - ✓ 他在做什么？ What is he doing?
  - ✗ 他已经回来了。 He has already come back. (from d70.2)
- **中**: 他在客厅看电视。 (Tā zài kè tīng kàn diàn shì.) He is watching TV in the living room.
  - ✓ 他在客厅看电视。 He is watching TV in the living room.
  - ✗ 他在做什么？ What is he doing? (from d70.3)
- **妈**: 我也有工作，为什么回家以后他在看电视可是我在做饭？ (Wǒ yě yǒu gōng zuò, wèi shén me huí jiā yǐ hòu tā zài kàn diàn shì kě shì wǒ zài zuò fàn?) I have a job, too. Why is it that he is watching TV but I am cooking after coming home?
  - ✓ 我也有工作，为什么回家以后他在看电视可是我在做饭？ I have a job, too. Why is it that he is watching TV but I am cooking after coming home?
  - ✗ 他在做什么？ What is he doing? (from d70.3)

## Lines left out

- d6.2 我姓谢，你呢？: 谢 is not a word in the checked lists
- d6.3 谢小姐，你好。我也姓谢。: 谢 is not a word in the checked lists
- d9.5 我姓李。: 李 is not a word in the checked lists
- d10.1 你哥哥有几个小孩？: 孩 is not a word in the checked lists
- d10.2 我大哥有一个女儿，二哥还没有小孩。你哥哥有小孩吗?: 孩 is not a word in the checked lists
- d10.3 我有一个姐姐，没有哥哥。她有一个男孩。: 孩 is not a word in the checked lists
- d11.2 还没有。你呢？: 还 has more than one reading (hai2, huan2)
- d11.3 我也还没有。: 还 has more than one reading (hai2, huan2)
- d12.6 我女朋友是老师，那个女孩是她的学生。: 孩 is not a word in the checked lists
- d14.5 有，他们的车也都是国车。: simplified and traditional differ: 有，他们的车也都是国车。 / 有，他們的車也都是美國車。
- d15.8 他姓谢。: 谢 is not a word in the checked lists
- d15.9 Ah! 谢老师是我的好朋友。: has English letters or digits
- d17.3 Ah! 你哥哥很高。这个是谁？: has English letters or digits
- d18.1 高先生，你有几个小孩？: 孩 is not a word in the checked lists
- d18.2 四个；我有三个女儿，还有一个儿子。: it can be split into words in two ways that read differently
- d20.2 有。: no English line to match it
- d20.6 他是美国人，他家在纽约。: 纽 is not a word in the checked lists
- d22.3 王先生，我姓李。: 李 is not a word in the checked lists
- d22.4 李小姐，你好！: 李 is not a word in the checked lists
- d23.1 你好！你叫什么名字？: no English line to match it
- d23.2 我叫李小朋。: 李 is not a word in the checked lists
- d23.3 你呢？: no English line to match it
- d23.4 我也姓李。我叫李贵。: 李 is not a word in the checked lists
- d24.3 你叫王名友吗？: 友 is not a word in the checked lists
- d24.4 我不叫王名友，叫王贵朋。: 友 is not a word in the checked lists
- d24.5 O…好！: has English letters or digits
- d25.2 我姓李。: 李 is not a word in the checked lists
- d25.3 李小姐，我姓王。: 李 is not a word in the checked lists
- d25.7 好！我叫你什么？叫你李小姐吗？: 李 is not a word in the checked lists
- d25.8 我叫李友友，请叫我友友。: 李 is not a word in the checked lists
- d26.1 李先生，你不忙吗？: 李 is not a word in the checked lists
- d27.1 请问，你姓李吗？: 李 is not a word in the checked lists
- d27.2 我不姓李，姓王。: 李 is not a word in the checked lists
- d28.1 李名中，我问你，你是中国人吗？: 李 is not a word in the checked lists
- d28.2 我不是李名中，我也不是中国人。: 李 is not a word in the checked lists
- d28.4 我叫王小京。: 京 is not a word in the checked lists
- d28.5 啊！你是王老师。你好吗？我也是老师，我姓李。: 啊 has more than one reading (a1, a2, a3, a4, a5)
- d28.6 李老师，你好!: 李 is not a word in the checked lists
- d29.5 李友生是中国名字，你不是李友生吗？: 李 is not a word in the checked lists
- d29.6 我是美国人，我叫 Lee Johnson.: has English letters or digits
- d30.3 我也是。我叫王国朋。: 朋 is not a word in the checked lists
- d30.4 啊！我也姓王。我叫王贵。: 啊 has more than one reading (a1, a2, a3, a4, a5)
- d31.6 他爸爸没有中文名字，他妈妈姓高，他的中文名字叫高友生。: 友 is not a word in the checked lists
- d32.6 她有一个女儿、一个儿子。: it can be split into words in two ways that read differently
- d35.2 我叫 Vincent Lee。: has English letters or digits
- d35.4 有，我有两个中文名字，一个叫李文生，一个叫文勝利。: written in traditional characters
- d35.5 啊，这两个名字都很好。: 啊 has more than one reading (a1, a2, a3, a4, a5)
- d36.5 Mmmm, 你姐姐的男朋友很高、很白，他是哪国人？: has English letters or digits
- d36.6 他是英国人。: 英 is not a word in the checked lists
- d39.4 我叫李友生。: 李 is not a word in the checked lists
- d41.6 我们有两个老师，一个姓高，一个姓谢。: 谢 is not a word in the checked lists
- d42.1 小李，你好！: 李 is not a word in the checked lists
- d42.2 Ah! 老王，是你！: has English letters or digits
- d42.8 好！明天晚上七点见。: simplified and traditional differ: 好！明天晚上七点见。 / 好！明天晚上七點見见。
- d43.3 你的同学王小英。你不认识她吗？: 英 is not a word in the checked lists
- d43.4 Ah！我认识她。你为什么问我认识不认识她？: has English letters or digits
- d43.6 Mmm，你妹妹也是德州大学的学生吗？我认识她吗？: has English letters or digits
- d43.7 你不认识她。她和王小姐都是纽约大学的学生。王小姐现在是德州大学的学生；可是二〇〇八年她是纽约大学的学生。: 纽 is not a word in the checked lists
- d44.2 七月十六号。: no English line to match it
- d44.3 七月十六！今天是七月十三号星期一，那你的生日是这个星期四。我那天晚上没有事儿，我请你吃晚饭，怎么样？: 儿 is not a word in the checked lists
- d44.7 Ah！二十岁生日是一个大生日。你一个人在纽约，你的家人都不在这儿。……Mmmm，我星期五晚上也没有事儿，我星期五晚上请你，怎么样？: has English letters or digits
- d44.8 Ah！谢谢，你人太好了！: has English letters or digits
- d44.9 不谢！我们几点见？: 谢 is not a word in the checked lists
- d45.4 我有四个。我还有一个儿子，他现在在外国。: it can be split into words in two ways that read differently
- d46.3 那你星期五晚上请我跟我妹妹吃晚饭，好不好？那天是她的生日，可是我爸妈这个月不在家，那天没有人请她吃饭。: it can be split into words in two ways that read differently
- d46.5 她今年十七岁，还没有男朋友。: 还 has more than one reading (hai2, huan2)
- d46.7 Ah！太谢谢你了！: has English letters or digits
- d46.8 不谢。你们喜欢吃哪国菜？中国菜还是美国菜？: 谢 is not a word in the checked lists
- d46.9 中国菜、美国菜（中国菜和美国菜）我都喜欢吃，可是我妹妹不喜欢吃中国菜。: has letters or digits (（）)
- d47.3 OH，是吗？为什么你认识她可是她不认识你？: has English letters or digits
- d48.1 二〇一二年有 365 天还是 366 天？: has English letters or digits
- d48.6 Ah！那你今年没有生日。: has English letters or digits
- d49.5 Oh，是吗？你女朋友今天为什么请客？: has English letters or digits
- d49.10 她也姓李，她的名字叫李贵美。: 李 is not a word in the checked lists
- d49.11 什么？李贵美是你女朋友？！我认识她，我们是好朋友。她还请谁？: 李 is not a word in the checked lists
- d49.12 她还请七、八个同学。: 还 has more than one reading (hai2, huan2)
- d50.6 Ah! 太好了！我这个星期六没有事，我也很爱看日本电影。我们几点见？: has English letters or digits
- d51.3 你周末也工作吗？你不看电视吗？: simplified and traditional differ: 你周末也工作吗？你不看电视吗？ / 你週末也工作嗎吗？你不看電視嗎？
- d52.1 Wow! 你家好大！你家有几个人？: has English letters or digits
- d52.4 我爸爸是医生，我妈妈是纽约大学的老师。: 纽 is not a word in the checked lists
- d52.11 Wow，你妹妹好美。她有没有男朋友？: has English letters or digits
- d52.12 我想她还没有男朋友，她太忙了。你问这个做什么？: 还 has more than one reading (hai2, huan2)
- d52.13 因為我也还没有女朋友，所以我很想认识她。她周末也很忙吗？: written in traditional characters
- d52.16 我爸爸这星期不在家，他去纽约看我妈妈。: 纽 is not a word in the checked lists
- d52.20 对，因为我觉得美国菜不好吃。可是因为我妈妈不在家，没有人做中国菜，所以我妹妹和我常吃美国菜。: it can be split into words in two ways that read differently
- d53.1 先生，你们想喝点儿什么？: 儿 is not a word in the checked lists
- d53.12 为什么？我也想喝点儿啤酒。: 儿 is not a word in the checked lists
- d53.13 因为你还太小了。: 还 has more than one reading (hai2, huan2)
- d53.14 Ah！对！你喝茶吧！: has English letters or digits
- d54.2 在哪儿？我看一下。Mmm, 我认识她，她是我的同学。你想认识她吗？: has English letters or digits
- d54.5 啊！李美英，是你！好久不见。: 啊 has more than one reading (a1, a2, a3, a4, a5)
- d55.1 小王星期五请客，对不对？你去了沒有？: written in traditional characters
- d55.10 Oh! 那个张小姐。她没有去。: has English letters or digits
- d55.11 那李小姐呢？她也是小王的老同学。: 李 is not a word in the checked lists
- d55.16 都有，还有茶、可乐和別的酒。: written in traditional characters
- d55.18 喝了，可是我只喝了两瓶。: 只 has more than one reading (zhi1, zhi3)
- d55.20 我们没有跳舞，只聊天、听音乐。: 只 has more than one reading (zhi1, zhi3)
- d55.21 你几点回家？我十点半睡觉，那个时候，你还没有回家。: 还 has more than one reading (hai2, huan2)
- d55.23 什么？你在他家一个晚上，只喝了两瓶啤酒？: 只 has more than one reading (zhi1, zhi3)
- d55.24 你只问我喝了几瓶啤酒，没有问我喝了別的酒没有？: written in traditional characters
- d55.25 那你喝了別的酒没有？: written in traditional characters
- d55.26 我喝了两瓶啤酒，还喝了三杯鸡尾酒。: 尾 is not a word in the checked lists
- d56.1 喂？: no English line to match it
- d56.4 大中，我是张友生。: 友 is not a word in the checked lists
- d56.5 Ah! 小张！你好！有事吗？: has English letters or digits
- d56.6 没有事。好久不见，所以我想给你打一个电话，问一下你怎么样。: it can be split into words in two ways that read differently
- d56.7 我很忙。这个星期有三个考试。昨天考了一个，今天考了一个，明天还要考一个。: 还 has more than one reading (hai2, huan2)
- d56.12 那你什么时候有空？: 空 has more than one reading (kong1, kong4)
- d56.13 我星期五以后才有空。这个周末我没有事，我要在家看书、睡觉。: 空 has more than one reading (kong1, kong4)
- d56.16 我们想看《一九一一》。: has letters or digits (《》)
- d56.17 别去看这个电影。我哥哥昨天去看了这个电影，他很不喜欢，他觉得这个电影很没有意思。: it can be split into words in two ways that read differently
- d56.24 四点半？没问题！…… Mmm，大中，我女朋友认识一个漂亮的女孩，她很想认识你。她可以不可以和我们一起来？: has English letters or digits
- d56.26 对。这位李小姐很漂亮！: 李 is not a word in the checked lists
- d57.5 我没有问，但是我想是张友生。: 友 is not a word in the checked lists
- d57.7 大中，我是张友生。: 友 is not a word in the checked lists
- d57.8 啊！小张，你好！有事吗？: 啊 has more than one reading (a1, a2, a3, a4, a5)
- d57.9 没有事，我女朋友要我问你觉得李小姐怎么样？: it can be split into words in two ways that read differently
- d57.11 那你为什么还没有给她打电话？我们给你们介绍以后，你没有给她打电话，所以我女朋友很不高兴。: 还 has more than one reading (hai2, huan2)
- d57.12 我这个星期太忙了，没有空。下个星期有两个中文考试。: 空 has more than one reading (kong1, kong4)
- d57.13 李小姐的中文很好，她在家跟她爸妈说中文，我想她可以帮你准备考试。: 李 is not a word in the checked lists
- d57.14 是吗？太好了！她家电话是几号？: it can be split into words in two ways that read differently
- d57.15 我找一下，啊！在这儿。她的电话是四五八二六九七。要是方便，你可不可以今天给她打？: 啊 has more than one reading (a1, a2, a3, a4, a5)
- d57.17 大中，我得给一个朋友打电话。: 得 has more than one reading (de2, de5, dei3)
- d58.1 昨天我在小张家认识了一个漂亮的女孩。她说她认识你。: 昨 is not a word in the checked lists
- d58.7 因为我想给她打电话(，)请她去看电影。: has letters or digits (())
- d58.8 那我得想一下。: 得 has more than one reading (de2, de5, dei3)
- d58.10 她是小李的女朋友，我不要小李不高兴。: 李 is not a word in the checked lists
- d58.11 那你別跟小李说，我也不跟他说。: written in traditional characters
- d59.2 还没有。我下个星期五才要跟他们见面。: 还 has more than one reading (hai2, huan2)
- d59.4 我下午六点要到他们家去，我女朋友给我们介绍了以后，我们要一起到一家饭馆去吃饭。她爸爸的弟弟上星期开了一家饭馆，我想我们要去这家饭馆吃吧！: it can be split into words in two ways that read differently
- d59.9 好啊！你想跟他们说什么？: 啊 has more than one reading (a1, a2, a3, a4, a5)
- d59.11 你可以説“我很高兴认识你们”。: written in traditional characters
- d59.13 別客氣。我也想问你一个问题。: written in traditional characters
- d59.16 对不起，不行，因为她还太小了，她爸爸说她还不可以有男朋友。: 还 has more than one reading (hai2, huan2)
- d60.1 李老师，请问我儿子学中文学得怎么样？: 李 is not a word in the checked lists
- d60.2 他写字写得很漂亮，可是说话说得太慢了。: 得 has more than one reading (de2, de5, dei3)
- d60.4 那太好了！我想小王以后中文可以说得很好。: 得 has more than one reading (de2, de5, dei3)
- d60.5 可是他爸爸好久没有说中文，所以他的中文也说得也不太好。: 得 has more than one reading (de2, de5, dei3)
- d60.8 我的中国朋友中文都说得太快了，因为他们不懂怎么跟外国人说话。: 得 has more than one reading (de2, de5, dei3)
- d60.9 您说得很对。我们去找别人。: 得 has more than one reading (de2, de5, dei3)
- d61.3 是吗？你考得怎么样？: 得 has more than one reading (de2, de5, dei3)
- d61.4 中文考试，我考得很好，可是英文考试，我考得很不好。: 得 has more than one reading (de2, de5, dei3)
- d61.5 你英文考试为什么考得不好？你没有准备吗？: 得 has more than one reading (de2, de5, dei3)
- d61.6 我准备了。可是我昨天晚上睡得不好，所以今天上午九点一刻才起来，十点才到学校。: 得 has more than one reading (de2, de5, dei3)
- d62.3 那个男的。: no English line to match it
- d62.4 Oh, 那是我儿子。: has English letters or digits
- d62.5 你有两个儿子，对不对？他是你的大儿子还是小儿子？: it can be split into words in two ways that read differently
- d63.2 我们有两个老师；一个姓白；一个姓李。: 李 is not a word in the checked lists
- d63.4 白老师是女的；李老师是男的。: 李 is not a word in the checked lists
- d66.4 今天老师教了我们三十个。二十个是难的，十个是容易的。我们明天就得考生词小考。可是老师说，她只考十个难的、五个容易的。: 得 has more than one reading (de2, de5, dei3)
- d67.2 我找我的《老人和海》。: has letters or digits (《》)
- d67.4 两本都不是我的。我的《老人和海》是英文的；那两本都是中文的。: has letters or digits (《》)
- d68.2 大中吗？我是小李。: 李 is not a word in the checked lists
- d68.3 小李！有事吗？: 李 is not a word in the checked lists
- d68.5 因为我昨天晚上睡得太晚了，所以今天早上十点才起来。: 得 has more than one reading (de2, de5, dei3)
- d68.6 你为什么睡得这么晚？: 得 has more than one reading (de2, de5, dei3)
- d68.12 Oh, 是吗？对不起。你喝得多不多？: has English letters or digits
- d68.13 不多。我只喝了一点儿。: 只 has more than one reading (zhi1, zhi3)
- d68.14 喝太多酒不好。以后別喝酒。: written in traditional characters
- d68.15 別跟我说这个，去跟文生说。他喝了很多瓶啤酒。…. 喂，小李，今天的考试难不难？: written in traditional characters
- d68.16 有一点难。我想大家都考得很不好。: 得 has more than one reading (de2, de5, dei3)
- d68.19 明天我们要开始学第十课，我今天晚上得在家预习一下。: 得 has more than one reading (de2, de5, dei3)
- d68.20 你要不要我到你家來跟你一起写功课？: written in traditional characters
- d68.21 什么？我们今天有功课？请快來。: written in traditional characters
- d68.22 好！我现在就來。: written in traditional characters
- d69.1 这个星期我们有两个考试。难的，大家都考得很好；可是容易的，很多人考得很不好。: 得 has more than one reading (de2, de5, dei3)
- d69.2 因为第一个是一个语法考试，所以您觉得很难。可是您教语法教得这么好，所以我们也都学得很好。大家都考得很好是很平常的事。: 得 has more than one reading (de2, de5, dei3)
- d69.3 他说得很对！第二个是一个生词考试。这课生词太多，所以这个考试我们考得不好。: 得 has more than one reading (de2, de5, dei3)
- d70.6 爸爸，妈妈有一点不高兴，你快去帮她做饭。: no English line to match it
- d70.7 我好累，今天开了两个会。你可不可以去帮她？: no English line to match it
- d70.8 不行。我今天功课好多。: no English line to match it
- d70.9 那你现在为什么在听音乐，没有在做功课？: no English line to match it
- d70.14 可以，可是录得不好。: 得 has more than one reading (de2, de5, dei3)
- d70.17 好啊！可是我下个月才可以给你买，因为我那时候才有钱。: 啊 has more than one reading (a1, a2, a3, a4, a5)
- d70.18 好！我现在的电脑还可以。: 还 has more than one reading (hai2, huan2)
- d70.19 去问你妈妈，吃了饭想不想跟我们一起去看电脑。我们看了电脑以后，我请你们两个去吃冰淇淋。: 淇 is not a word in the checked lists
